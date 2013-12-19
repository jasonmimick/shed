#!/bin/bash
# test.sh
# Test script for shed.
# This will pull Sample.Person.cls from the SAMPLES namespace
# and then try to POST it back
class=Sample.Person.cls
ns=SAMPLES
rm $class
./shed.sh --namespace $ns get $class > $class
./shed.sh --namespace $ns post $class
rm $class

