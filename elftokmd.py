#!/bin/python3
import subprocess
import sys 

def main():
    file = sys.argv[1] 
    parse(file) 
    pass

def parse(inFilePath : str):
    file_contents = get_obj_dump(inFilePath) 

    initLine = True
    commentBuffer = []
    address = 0
    split_line = file_contents.splitlines() 
    print("KMD")
    for line in split_line:
           
        if (initLine is True):
            initLine = False
            commentBuffer = []
            continue

        if (line.startswith("Dissasembly")):
            initLine = True 
            continue

        if (line == ""):
            initLine = True 
            continue


        if (line.startswith("SRCSRC")):
            commentBuffer.append(line.removeprefix("SRCSRC:")) 
            continue
           
        
        address = int(line.split(':')[0], base=16)
        data = line.split(':')[1].split()[0]
        assembly = "".join(line.split(':')[1].split()[1:])

        print(f"{hex(address)} : {data} ; {assembly}")
        for comment in commentBuffer:
            print(f"{hex(address)} :  ; {comment}")

        commentBuffer = []
        

def get_obj_dump(path) -> str:
    return subprocess.check_output(['./elftokmd.sh', path]).decode('utf-8')

main()