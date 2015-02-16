#!/usr/bin/perl

# 2014-12-24 bstroess
# add some content in the resulting html page asciidoc did produce


#############################################################################
# modules and variables
#############################################################################

use strict;
use Data::Dumper;
use Getopt::Long;
use Tie::IxHash;
use HTML::Template;

my ($file, $tmpdir, $tmpfile, $includes_dir, $in, @anchors);
my ($template_head, $template_foot, $anchors_available );


#############################################################################
# command line parameters
#############################################################################

GetOptions ("file|F=s"         => \$file,
            "includes-dir|I=s" => \$includes_dir,
            "tmpdir|T=s"       => \$tmpdir)
    or die("Error in command line arguments\n");

if ($file eq "" || $tmpdir eq "" || $includes_dir eq "") {
    print <<EOF

call using
$0 --file|-F <FILE> --tmpdir|-T <TMPDIR> --includes-dir|-I <INCLUDES_DIR>

EOF
;
    exit(1);
}


#############################################################################
# parse html page for anchors
#############################################################################

@anchors = ();              # initialize an array of all anchor references
$anchors_available = 0;

open (IN, "<$file") or die "unable to read from html file $file: $!\n";
    while ($in = <IN>) {
        my %anchor_hash;      # get a fresh hash to keep infos about the current anchor

        # search for something like:
        # <h2 id="_weitere_bereiche_auf_berny_8217_s_website">Weitere Bereiche auf Berny&#8217;s Website</h2>
        if ($in =~ m/<h2 id="(_.+)">(.+)<\/h2>/) {
            $anchor_hash{'ANCHOR'} = $1;
            $anchor_hash{'DESCR'} = $2;
            # print "      section: $anchor_hash{'DESCR'}\n";

            # the crucial step - push a reference to this hash into the anchors array
            push(@anchors, \%anchor_hash);
            $anchors_available = 1;
        }
    }
close (IN);



#############################################################################
# rewrite html page
#############################################################################

$template_foot = HTML::Template->new(filename => "$includes_dir/foot.tmpl");
$template_head = HTML::Template->new(filename => "$includes_dir/head.tmpl");
$template_head->param(ANCHORS_AVAILABLE => $anchors_available);

# assign reference to the anchors array to ANCHORS_LOOP variable of HTML::template
$template_head->param(ANCHOR_LOOP => \@anchors);

$tmpfile = `mktemp $tmpdir/postprocessor.XXXXXXXX` or die "unable to create tmp file in $tmpdir: $!\n";
system("cp $file $tmpfile");

open (IN, "<$tmpfile") or die "unable to read from tmpfile $tmpfile: $!\n";
open (OUT, ">$file") or die "unable to write to $file: $!\n";

    while ($in = <IN>) {
        if ($in =~ m/<\/body/) { print OUT $template_foot->output; }
        print OUT $in;
        if ($in =~ m/<body/) { print OUT $template_head->output; }
    }

close (OUT);
close (IN);

system("rm $tmpfile");
