#!/usr/bin/perl

# 2014-12-08 booboo
# read dates and topics for linux cafe from an ini file
# write a table for the website as well as an ical file

use strict;
use Config::IniFiles;
use Data::Dumper;
use Time::Local;
use Getopt::Long;
use Digest::MD5 qw(md5_base64);

my (%calendar_hash, $entry, $year, $month, $day, $epoch, $title, $location, $location_section_id);
my (@localtime, $date, $timeslot_id, $calendar_ini, $outfile_table, $outfile_ical, $uid, $summary_ical);
my ($skip_ical, $timefrom, $timestamp_from_ical, $timeto, $timestamp_to_ical, $date_today, @stat_infile);
my (@mtime_infile, $last_modified_for_ical, $location_ical, $ics_include_file, $in, $description_ical);
my ($outfile_latest);
my $latest_written = 0;
my @day_of_week = ( "So", "Mo", "Di", "Mi", "Do", "Fr", "Sa");

GetOptions ("read-from|R=s"      => \$calendar_ini,
            "include|I=s"        => \$ics_include_file,
            "write-asciidoc|A=s" => \$outfile_table,
            "write-ical|I=s"     => \$outfile_ical)
    or die("Error in command line arguments\n");

if ($calendar_ini eq "" || $outfile_table eq "" || $outfile_ical eq "") {
    print <<EOF

call using
$0 --read-from <INFILE> [ --include <ICS_FILE> ] --write-asciidoc <OUTFILE_ASCIIDOC> --write-ical <OUTFILE_ICAL>

EOF
;
    exit(1);
}

$outfile_latest = "${outfile_table}.latest";
tie %calendar_hash, 'Config::IniFiles', ( -file => $calendar_ini );
@localtime = localtime(time);
$localtime[5] += 1900;
$localtime[4]++;
$localtime[4] = sprintf("%02d", $localtime[4]);
$localtime[3] = sprintf("%02d", $localtime[3]);
$date_today = "date:$localtime[5]-$localtime[4]-$localtime[3]";

# print Dumper(\%calendar_hash);

#
# last modified time for ICAL
#

@stat_infile = stat($calendar_ini);
@mtime_infile = localtime($stat_infile[9]);
$mtime_infile[5] += 1900;
$mtime_infile[4]++;
$mtime_infile[4] = sprintf("%02d", $mtime_infile[4]);
$mtime_infile[3] = sprintf("%02d", $mtime_infile[3]);
$mtime_infile[2] = sprintf("%02d", $mtime_infile[2]);
$mtime_infile[1] = sprintf("%02d", $mtime_infile[1]);
$mtime_infile[0] = sprintf("%02d", $mtime_infile[0]);

$last_modified_for_ical = "$mtime_infile[5]$mtime_infile[4]$mtime_infile[3]T$mtime_infile[2]$mtime_infile[1]$mtime_infile[0]Z";


open(ASCIIDOC, ">$outfile_table") or die "unable to write to asciidoc outfile $outfile_table: $!\n";
open(ICAL, ">$outfile_ical") or die "unable to write to ical outfile $outfile_ical: $!\n";

    # ICAL header
    print ICAL "BEGIN:VCALENDAR\n";
    print ICAL "VERSION:2.0\n";
    print ICAL "PRODID:Repair Cafe Altdorf Calendar 0.1\n";
    print ICAL "X-WR-CALNAME:Repair Cafe Altdorf Terminplan\n";

    # include entries from prepared ics include file
    if ($ics_include_file ne "") {
        open (INCLUDE, "<$ics_include_file") or die "unable to read ics include file $ics_include_file: $!\n";
            print "      copying entries from ics include file $ics_include_file\n";
            while ($in = <INCLUDE>) {
                print ICAL $in;
            }
        close (INCLUDE);
    }

    foreach $entry (sort keys %calendar_hash) {
        $skip_ical = 1;
        next if ($entry !~ m/^date:(\d\d\d\d)-(\d\d)-(\d\d)\s*$/);

        if ($entry lt $date_today) {
            print "      skipping $entry because it is in the past\n";
            next;
        } else {
            print "      generating entry for $entry\n";
        }

        #
        # column for date and time for ASCIIDOC
        #

        $year = $1;
        $month = $2;
        $day = $3;
        $epoch = timelocal(0,0,0,$day,$month-1,$year);
        @localtime = localtime($epoch);
        $date = "[rcdate]#" . $day_of_week[$localtime[6]] . " $day.$month.$year#";

        if (exists $calendar_hash{$entry}{"timeslot"} && $calendar_hash{$entry}{"timeslot"} ne "") {
            $timeslot_id = "timeslot:" . $calendar_hash{$entry}{"timeslot"};
            if (exists $calendar_hash{$timeslot_id}{"timefrom"} && $calendar_hash{$timeslot_id}{"timefrom"} =~ m/^\d\d:\d\d$/ &&
            exists $calendar_hash{$timeslot_id}{"timeto"} && $calendar_hash{$timeslot_id}{"timeto"} =~ m/^\d\d:\d\d$/ ) {
                $date .= " +\n[rctime]#" . $calendar_hash{$timeslot_id}{"timefrom"} . " - " . $calendar_hash{$timeslot_id}{"timeto"} . " Uhr#";
                # ical entry can only be created if we have all these information
                $skip_ical = 0;
            }
        }

        #
        # date and time for ICAL
        #
        if ($skip_ical == 0) {
            $timefrom = $calendar_hash{$timeslot_id}{"timefrom"} . "00";
            $timefrom =~ s/://g;
            $timestamp_from_ical = "TZID=Europe/Berlin:${year}${month}${day}T$timefrom";

            $timeto = $calendar_hash{$timeslot_id}{"timeto"} . "00";
            $timeto =~ s/://g;
            $timestamp_to_ical = "TZID=Europe/Berlin:${year}${month}${day}T$timeto";
        } else {
            print "WARINING: Skipping entry for $entry: not all requested information is available in the infile\n";
        }

        #
        # column for title and focus for ASCIIDOC
        #

        $title = "[rctitle]#Repair Café#";
        if (exists $calendar_hash{$entry}{"focus"} && $calendar_hash{$entry}{"focus"} ne "") {
            $title .= " +\n" . "[rcfocus]#Reparaturschwerpunkt: " . $calendar_hash{$entry}{"focus"} . "#";
        } else {
            $title .= " +\n" . "[rcnofocus]#Reparaturschwerpunkt wird noch bekannt gegeben#";
        }

        #
        # column for title and focus for ICAL
        #

        $summary_ical = "Repair Cafe Altdorf";
        if (exists $calendar_hash{$entry}{"focus"} && $calendar_hash{$entry}{"focus"} ne "") {
            $description_ical = "Reparaturschwerpunkt: " . $calendar_hash{$entry}{"focus"};
        } else {
            $description_ical = "Reparaturschwerpunkt wird noch bekannt gegeben";
        }

        #
        # column location for ASCIIDOC
        #

        $location = "";
        $location_section_id = "";
        if (exists $calendar_hash{"location:" . $calendar_hash{$entry}{"location"}}) {
            # we have a location definition
            $location_section_id="location:" . $calendar_hash{$entry}{"location"};

            if (exists $calendar_hash{$location_section_id}{"shortname"} && $calendar_hash{$location_section_id}{"shortname"} ne "") {
                if (exists $calendar_hash{$location_section_id}{"detailslink"} && $calendar_hash{$location_section_id}{"detailslink"} ne "") {
                    $location = "link:" . $calendar_hash{$location_section_id}{"detailslink"};
                    $location .= "[" . $calendar_hash{$location_section_id}{"shortname"} . "]";
                } else {
                    $location = $calendar_hash{$location_section_id}{"shortname"};
                }
            }
            if (exists $calendar_hash{$location_section_id}{"room"} && $calendar_hash{$location_section_id}{"room"} ne "") {
                if ($location ne "") { $location .= " +\n" }
                $location .= "[rcroom]#" . $calendar_hash{$location_section_id}{"room"} . "#";
            }
        }

        #
        # column location for ICAL
        #

        $location_ical = "";
        if (exists $calendar_hash{"location:" . $calendar_hash{$entry}{"location"}}) {
            # we have a location definition
            $location_section_id="location:" . $calendar_hash{$entry}{"location"};

            if (exists $calendar_hash{$location_section_id}{"streetaddress"} && $calendar_hash{$location_section_id}{"streetaddress"} ne "") {
                $location_ical = $calendar_hash{$location_section_id}{"streetaddress"}
            }
            if (exists $calendar_hash{$location_section_id}{"room"} && $calendar_hash{$location_section_id}{"room"} ne "") {
                if ($location_ical ne "") { $location_ical .= ", " }
                $location_ical .= $calendar_hash{$location_section_id}{"room"};
            }
        }
        # commas need to be escaped in ical entries
        $location_ical =~ s/,/\\,/g;


        #
        # description for ICAL
        #

        if (exists $calendar_hash{$entry}{"description"} && $calendar_hash{$entry}{"description"} ne "") {
            $description_ical = $calendar_hash{$entry}{"description"};
        }

        #
        # UID for this entry for ICAL
        #

        $uid = md5_base64($entry);
        $uid =~ s/[^A-Za-z0-9]//g;
        $uid = substr($uid, 0, 10);

        #
        # generate output files
        #

        print ASCIIDOC "|$date|$title|$location\n\n";

        print ICAL "BEGIN:VEVENT\n";
        print ICAL "CREATED;VALUE=DATE-TIME:$last_modified_for_ical\n";
        print ICAL "UID:$uid\n";
        print ICAL "LAST-MODIFIED;VALUE=DATE-TIME:$last_modified_for_ical\n";
        print ICAL "DTSTAMP;VALUE=DATE-TIME:$last_modified_for_ical\n";
        print ICAL "SUMMARY:$summary_ical\n";
        print ICAL "DESCRIPTION:$description_ical\n";
        print ICAL "DTSTART;VALUE=DATE-TIME;$timestamp_from_ical\n";
        print ICAL "DTEND;VALUE=DATE-TIME;$timestamp_to_ical\n";
        print ICAL "LOCATION:$location_ical\n";
        print ICAL "CLASS:PUBLIC\n";
        print ICAL "BEGIN:VALARM\n";
        print ICAL "TRIGGER;VALUE=DURATION:-P1D\n";
        print ICAL "ACTION:DISPLAY\n";
        print ICAL "DESCRIPTION:Default Event Notification\n";
        print ICAL "X-WR-ALARMUID:${uid}-notify\n";
        print ICAL "END:VALARM\n";
        print ICAL "END:VEVENT\n";

        #
        # write "latest" file for include in start page
        #
        if ($latest_written == 0) {
            open(LATEST, ">$outfile_latest") or die "unable to write to asciidoc latest file $outfile_latest: $!\n";
                print LATEST "*" . $day_of_week[$localtime[6]] . " $day.$month.$year*";
                if (exists $calendar_hash{$timeslot_id}{"timefrom"} && $calendar_hash{$timeslot_id}{"timefrom"} =~ m/^\d\d:\d\d$/) {
                    print LATEST " ab *" . $calendar_hash{$timeslot_id}{"timefrom"} . " Uhr*";
                }
                print LATEST "\n";
            close(LATEST);
            $latest_written = 1;
        }

    }

    # ICAL footer
    print ICAL "END:VCALENDAR\n";

close(ICAL);
close(ASCIIDOC);
