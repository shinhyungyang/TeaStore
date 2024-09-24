#!/bin/bash

source 'functions.sh'

waitForFullstartup $1
return_code=$?

exit $return_code
