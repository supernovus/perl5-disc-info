#!/bin/sh

genisoimage -A "TestApp" -copyright "copyright.txt" -publisher "me" -p "myself" -sysid "any" -volset "testvolume" -V "TestDisc" -o test.iso test-files