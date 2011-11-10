package Disc::Info;

use strict;
use warnings;
use Carp;

use DateTime;

our $VERSION = 1.0;

use Exporter 'import';
our @EXPORT    = qw(get_disc_info);
our @EXPORT_OK = qw(get_disc_info);

## Date fields, an array reference, of array references.
## Format: [ FIELD_NAME, FIELD_OFFSET, FIELD_SIZE, FIELD_TYPE ]
##
our $DATA_FIELDS = [
  ['fs',        32769,   5, 0],
  ['os',        32776,  32, 0],
  ['name',      32808,  32, 0],
  ['setid',     32958, 128, 0],
  ['publisher', 33086, 128, 0],
  ['preparer',  33214, 128, 0],
  ['appid',     33342, 128, 0],
  ['copyright', 33470,  32, 0],
  ['cdate',     33581,  16, 1],
  ['coff',      33597,   1, 2],
  ['mdate',     33598,  16, 1],
  ['moff',      33614,   1, 2],
  ['xdate',     33615,  16, 1],
  ['xoff',      33631,   1, 2],
  ['edate',     33632,  16, 1],
  ['eoff',      33648,   1, 2],
];

sub get_disc_info {
  my ($device, $raw) = @_;
  if (!defined $device) {
    croak "Device not specified.";
  }
  my %info;
  open(my $dev, "<:raw", $device);
  my $curdate; ## Stores the last used date field.
  for my $field (@$DATA_FIELDS) {
    my ($name, $offset, $size, $type) = @$field;
    seek($dev, $offset, 0) or croak "Could not seek to offset for $name.";
    my $value;
    my $read = read($dev, $value, $size);
    warn "only read $read bytes, not $size on $name field." if $read != $size;
    ## If raw mode is used, we don't convert stuff.
    if (!$raw) {
      if ($type == 0) {
        ## A normal value, strip off leading and trailing whitespace.
        $value =~ s/^\s+//g;
        $value =~ s/\s+$//g;
      }
      elsif ($type == 1) {
        ## A date stamp.
        my ($year, $month, $day, $hour, $minute, $second, $cent) = unpack("A4A2A2A2A2A2A2", $value);
        if ($month == 0) {
          $value = 0;
          undef($curdate);
        }
        else {
          $curdate = DateTime->new(
            year   => 0+$year,
            month  => 0+$month,
            day    => 0+$day,
            hour   => 0+$hour,
            minute => 0+$minute,
            second => 0+$second
          );
          $value = $curdate;
        }
      }
      elsif ($type == 2) {
        ## A date offset. Let's set the timezone on the previous DateTime.
        my $interval = unpack("c1", $value);
        my $offset = $interval * 15;
        my $hours = int($offset / 60);
        my $mins  = $offset % 60;
        $value = sprintf("%+03d%02d", $hours, $mins);
        if (defined $curdate) {
          $curdate->set_time_zone($value);
        }
      }
    }
    $info{$name} = $value;
  }
  return \%info;
}

## End of package.
1;
