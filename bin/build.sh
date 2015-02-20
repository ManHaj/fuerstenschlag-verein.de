#!/bin/bash

# 2014-04-23 booboo
# script to build html from all asciidoc files in asciidoc directory

BINDIR=$(dirname $0)
ADDIR=$BINDIR/../asciidoc
HTMLDIR=$BINDIR/../www
RESOURCESDIR=$BINDIR/../web-resources
POSTPROCESSOR_INCLUDES_DIR=$BINDIR/../postprocessor-includes

which asciidoc > /dev/null 2> /dev/null
RC=$?
if [ $RC -ne 0 ]
then
    echo asciidoc not found, aborting $0
    exit 1
fi

if [ ! -d $HTMLDIR ]
then
    mkdir -p $HTMLDIR || exit 1
fi

echo "### working in $HTMLDIR:"

TMP_SITEMAP=$(mktemp --tmpdir=$HTMLDIR)
echo "   creating new sitemap in $TMP_SITEMAP"

echo '<?xml version="1.0" encoding="UTF-8"?>' > $TMP_SITEMAP
echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' >> $TMP_SITEMAP

if [ ! -z $1 ]
then
    CMDEXTENSION="-name *$1*"
fi

for FILE in $(find $ADDIR -name "*.asciidoc" $CMDEXTENSION)
do
    MTIME=$(stat -c %y $FILE | cut -d' ' -f1)
    BASENAME=$(basename $FILE .asciidoc)
    DIRNAME=$(dirname $FILE)
    DESTDIR=$(echo $DIRNAME | sed -e s/.*asciidoc//)
    AREA=$(echo $DESTDIR | cut -d/ -f2)
    mkdir -p $HTMLDIR/$DESTDIR/
    echo "   creating $HTMLDIR/$DESTDIR/$BASENAME.html"
    asciidoc -b xhtml11 -o $HTMLDIR/$DESTDIR/$BASENAME.html $FILE
    echo "    <url>" >> $TMP_SITEMAP
    echo "        <loc>http://wiki.gluga.de/$BASENAME.html</loc>" >> $TMP_SITEMAP
    echo "        <lastmod>$MTIME</lastmod>" >> $TMP_SITEMAP
    echo "    </url>" >> $TMP_SITEMAP
done

echo '</urlset>' >> $TMP_SITEMAP
echo "   renaming sitemap to sitemap.xml"
mv $TMP_SITEMAP $HTMLDIR/sitemap.xml || rm $TMP_SITEMAP
chmod 644 $HTMLDIR/sitemap.xml

echo
echo "### syncing static files"
rsync -aP $RESOURCESDIR/www/* $HTMLDIR
