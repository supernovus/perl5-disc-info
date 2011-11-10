#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 38;
use Test::Exception;

BEGIN { 
  push @INC, "./lib"; 
  use_ok('Disc::Info');
}

## Update if we regenerate the ISO image.
my @DATE     = (2011,11,10,11,23,39);
my $ISO_DATE = sprintf("%04d-%02d-%02dT%02d:%02d:%02d", @DATE);

## My timezone in HHMM format.
my $TZ_LOCAL = "-0800";
## My timezone in minutes.
my $TZ_OFFSET = -28800;

my $info;
lives_ok { $info = get_disc_info('./t/test.iso'); } 'get_disc_info() lives.';

sub is_field {
  my ($field, $what, $msg) = @_;
  if (!$msg) {
    $msg = "$field field is correct.";
  }
  is $info->{$field}, $what, $msg;
}

sub is_date {
  my ($field, $year, $month, $day, $hour, $minute, $second, $offset) = @_;
  if (!defined $offset) {
    $offset = $TZ_OFFSET;
  }
  is $info->{$field}->year,   $year,   "$field year";
  is $info->{$field}->month,  $month,  "$field month";
  is $info->{$field}->day,    $day,    "$field day";
  is $info->{$field}->hour,   $hour,   "$field hour";
  is $info->{$field}->minute, $minute, "$field minute";
  is $info->{$field}->second, $second, "$field second";
  is $info->{$field}->offset, $offset, "$field offset";
}

## Test normal fields.
is_field 'appid',     'TestApp';
is_field 'copyright', 'copyright.txt';
is_field 'publisher', 'me';
is_field 'preparer',  'myself';
is_field 'os',        'any';
is_field 'setid',     'testvolume';
is_field 'name',      'TestDisc';
is_field 'cdate',     $ISO_DATE;
is_field 'mdate',     $ISO_DATE;
is_field 'edate',     $ISO_DATE;
is_field 'xdate',     0;
is_field 'fs',        'CD001';

## Test date fields.
is_date 'cdate', @DATE;
is_date 'mdate', @DATE;
is_date 'edate', @DATE;

## Test offset fields.
is_field 'coff', $TZ_LOCAL;
is_field 'moff', $TZ_LOCAL;
is_field 'eoff', $TZ_LOCAL;
