#!/usr/bin/env python

import argparse
import xml.etree.ElementTree as ET

def parsesubtag(xmlroot,task,tag, metatask=False):

    txt = None

    if metatask:
        for child in xmlroot.findall(f'./metatask[@name="{task}"]/task/{tag}'):
            txt = child.text
    else:
        for child in xmlroot.findall(f'./task[@name="{task}"]/{tag}'):
            txt = child.text
    return txt

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Decode FV3LAM_wflow.xml")
    parser.add_argument("xmlfile",  help="XML file path and name" )
    parser.add_argument("-t", "--task",  help="task name")
    parser.add_argument("-g", "--tag",   help="tag name")
    parser.add_argument("-m", "--meta",  action="store_true", help="metatask for run_post")
    parser.add_argument("-d", "--debug", action="store_true", help="debug output")

    args = parser.parse_args()

    tree = ET.parse(args.xmlfile)
    root = tree.getroot()

    if args.debug:
        for child in root:  #.findall('./metatask/*'):
            print(child.tag, child.attrib)
        print(" ")

    txt = parsesubtag(root,args.task,args.tag, args.meta)

    print(txt)

