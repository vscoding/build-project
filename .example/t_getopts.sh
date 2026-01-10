#!/bin/bash

while getopts ":a:b:c:" opt; do
  case ${opt} in
    a)
      echo "You entered -a with value: $OPTARG"
      ;;
    b)
      echo "You entered -b with value: $OPTARG"
      ;;
    c)
      echo "You entered -c with value: $OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" 1>&2
      exit 1
      ;;
    :)
      echo "Invalid option: -$OPTARG requires an argument" 1>&2
      exit 1
      ;;
  esac
done
