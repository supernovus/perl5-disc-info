=head1 NAME

Disc::Info - Extract info from ISO discs/images

=head1 DESCRIPTION

Retrieves the metadata info from ISO9660 discs or images.
The date fields are returned as DateTime objects.

Using this on a physical disc only works in OSes where you can have a file
representing the optical drive. So Linux, Unix, Mac OS X, etc.

I'm not sure if this is possible with Windows, if somone knows a way,
let me know. Using it on an .iso file should work on any OS.

Supports both an object-oriented interface, and a procedural/functional one.

=head1 USAGE

  ## Object-oriented (returns a Disc::Info object.)
  use Disc::Info;
  my $disc = Disc::Info->get("/dev/cdrom");
  say $disc->name . " was created in the year " . $disc->date->year;

  ## Procedural (returns a Hash reference.)
  use Disc::Info  'get_disc_info';
  my $disc = get_disc_info("/dev/cdrom");
  say $disc->{name} . " was created in the year " . $disc->{cdate}->year;

=cut

package Disc::Info;

use strict;
use warnings;
use Carp;

use DateTime;

## Version number is two digits. The first represents a stable API.
## The second represents the number of updates in that API.
our $VERSION = 2.1;
## The release date in ISO format.
our $RELEASE = "2011-11-13T07:30:00-0800"; 

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

our $SKIP_STRIP    = 1;  ## Do not strip whitespace from text fields.
our $SKIP_DATETIME = 2;  ## Do not convert date fields into DateTime.
our $SKIP_OFFSET   = 4;  ## Do not unpack and convert offset fields.

=head1 EXPORTABLE FUNCTIONS

=over1

=item get_disc_info

Queries the given disc or image, and returns a Hash reference containing the
metadata information.

  $hashref = Disc::Info::get_disc_info($path);

Also supports an optional second parameter, which is a bitmask:

  1     Don't strip leading and trailing whitespace from fields.
  2     Don't convert date fields into DateTime objects.
  4     Don't unpack and convert offset fields.

See the PUBLIC OBJECT METHODS section below, for each method, the field
it represents is listed in {brackets}. Those fields will be returned by
this function.

=cut

sub get_disc_info {
  my ($device, $mode) = @_;
  if (!defined $device) {
    croak "Device/image not specified.";
  }
  elsif (!-e $device) {
    croak "Device/image not found.";
  }
  my $strip_text    = 1;  ## Strip whitespace from fields.
  my $make_datetime = 1;  ## Turn date fields into DateTime objects.
  my $unpack_offset = 1;  ## Unpack offsets.
  if (defined $mode) {
    if (($mode & $SKIP_STRIP) == $SKIP_STRIP) {
      $strip_text = 0;
    }
    if (($mode & $SKIP_DATETIME) == $SKIP_DATETIME) {
      $make_datetime = 0;
    }
    if (($mode & $SKIP_OFFSET) == $SKIP_OFFSET) {
      $unpack_offset = 0;
    }
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
    if ($type == 0 && $strip_text) {
      ## A normal value, strip off leading and trailing whitespace.
      $value =~ s/^\s+//g;
      $value =~ s/\s+$//g;
    }
    elsif ($type == 1 && $make_datetime) {
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
    elsif ($type == 2 && $unpack_offset) {
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
    $info{$name} = $value;
  }
  return \%info;
}

=back

=head1 CLASS METHODS

=over 1

=item get

Create a Disc::Info object, populated with the metadata from the
requested disc/image.

  my $disc = Disc::Info->get($path);

=item new

An alias to get(), for compatibility with most Perl libraries.

=item load

An alias to get(), for compatibility with Disc::Info 2.0.

=cut

sub get {
  my ($class, $disc) = @_;
  my $self = get_disc_info($disc);
  return bless $self, $class;
}

sub new {
  return get(@_);
}

sub load {
  return get(@_);
}

=back

=head1 PUBLIC OBJECT METHODS

=over 1

=item filesystem

A special code representing the file system.

{fs}

=cut

sub filesystem {
  my $self = shift;
  return $self->{fs};
}

=item os

The operating system used by or expected for use with this disc.

{os}

=cut

sub os {
  my $self = shift;
  return $self->{os};
}

=item name

The name of the disc, also known as the volume label.

{name}

=cut

sub name {
  my $self = shift;
  return $self->{name};
}

=item setid

An identifier of a disc set, if this disc belongs to one.

{setid}

=cut

sub setid {
  my $self = shift;
  return $self->{setid};
}

=item publisher

The publisher of the disc.

{publisher}

=cut

sub publisher {
  my $self = shift;
  return $self->{publisher};
}

=item preparer

The preparer of the disc.

{preparer}

=cut

sub preparer {
  my $self = shift;
  return $self->{preparer};
}

=item appid

The application which created this disc.

{appid}

=cut

sub appid {
  my $self = shift;
  return $self->{appid};
}

=item copyright

The copyright information for this disc. Usually a filename.

{copyright}

=cut

sub copyright {
  my $self = shift;
  return $self->{copyright};
}

=item date

The date the disc was created.

{cdate}

=item created

An alias for date().

=cut

sub date {
  my $self = shift;
  return $self->{cdate};
}
sub created {
  my $self = shift;
  return $self->{cdate};
}

=item modified

The date the disc was modified last.

{mdate}

=cut

sub modified {
  my $self = shift;
  return $self->{mdate};
}

=item effective

The effective date of the disc.

{edate}

=cut

sub effective {
  my $self = shift;
  return $self->{edate};
}

=item expires

The expiry date of the disc (if any, uncommon use.)

{xdate}

=cut

sub expires {
  my $self = shift;
  return $self->{xdate};
}

=item offset

Return the offset field from one of the date fields.

  my $created_offset = $disc->offset();
  ## {coff} field.

  my $modified_offset = $disc->offset('modified');
  ## {moff} field.

  my $effective_offset = $disc->offset('effective');
  ## {eoff} field.

  my $expires_offset = $disc->offset('expires');
  ## {xoff} field.

=cut

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

=back

=head1 DEPENDENCIES

=over 1

=item DateTime

Used to make the date fields useful.

=item Test::More

Used for testing.

=item Test::Exception

Used for testing.

=back

=head1 AUTHOR

Timothy Totten <https://github.com/supernovus/>

=head1 LICENSE

Artistic License 2.0

=cut

## End of package.
1;
