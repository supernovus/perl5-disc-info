package Disc::Info;

use strict;
use warnings;
use Carp;

use DateTime;

our $VERSION = 2.0;

use Exporter 'import';
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
    croak "Device/image not specified.";
  }
  elsif (!-e $device) {
    croak "Device/image not found.";
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

## Optional OO form.

## We use load() instead of new() as it makes more sense.
sub load {
  my ($class, $disc) = @_;
  my $self = get_disc_info($disc);
  return bless $self, $class;
}

## Wrappers for the fields.

sub filesystem {
  my $self = shift;
  return $self->{fs};
}

sub os {
  my $self = shift;
  return $self->{os};
}

sub name {
  my $self = shift;
  return $self->{name};
}

sub setid {
  my $self = shift;
  return $self->{setid};
}

sub publisher {
  my $self = shift;
  return $self->{publisher};
}

sub preparer {
  my $self = shift;
  return $self->{preparer};
}

sub appid {
  my $self = shift;
  return $self->{appid};
}

sub copyright {
  my $self = shift;
  return $self->{copyright};
}

## The obscure date fields are given nicer names here.

## We give two different names for cdate: date and created.
sub date {
  my $self = shift;
  return $self->{cdate};
}
sub created {
  my $self = shift;
  return $self->{cdate};
}

sub modified {
  my $self = shift;
  return $self->{mdate};
}

sub effective {
  my $self = shift;
  return $self->{edate};
}

sub expires {
  my $self = shift;
  return $self->{xdate};
}

## Offset, not typically used, but available anyway.
sub offset {
  my ($self, $want) = @_;
  if (defined $want) {
    if ($want eq 'modified') {
      return $self->{moff};
    }
    elsif ($want eq 'effective') {
      return $self->{eoff};
    }
    elsif ($want eq 'expires') {
      return $self->{xoff};
    }
  }
  return $self->{coff};
}

## End of package.
1;
