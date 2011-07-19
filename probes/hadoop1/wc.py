#!/usr/bin/python
import sys
import re
  
def main(argv):
  line = sys.stdin.readline()
  count = 1
  pattern = re.compile("[a-zA-Z][a-zA-Z0-9]*")
  try:
    while line:
      for word in  pattern.findall(line):
        print  "LongValueSum" + str(count) +":" + word.lower() + "\t" + "1"
        count = count + 1
      line =  sys.stdin.readline()
  except "end of file":
    return None
if __name__ == "__main__":
  main(sys.argv)
  