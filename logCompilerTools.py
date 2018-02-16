#!/usr/sfw/bin/python

import sys
from commands import getoutput

compiler_Tools = { "perl" : " perl -v | head -n 2  |tail -1|awk '{ print  $4}'", 
                   "SMILE_compiler" : "sc -v | head -n 2  |tail -1|awk '{ print  $3}'", 
                   "ld" : "ld -V",
                   "cc" : "cc -V",
                   "CC" : "CC -V" }
                   
environment_variables = { "Build date" : "date",
                          "Hostname" : "hostname",
                          "OS_Version" : "uname -a",
                          "NID_RELEASE" : "echo $NID_RELEASE",
                          "NID_DEV" : "echo $NID_DEV",
                          "NID_SYBASE" : "echo $NID_SYBASE",
                          "NID_IPD" : "echo $NID_IPD",
                          "ACE_ROOT" : "cat /tmp/SCMVariableData.txt | awk '/ACE_ROOT=/{print $0}' | sed -e 's/ACE_ROOT=//'",
                          "TAO_ROOT" : "cat /tmp/SCMVariableData.txt | awk '/TAO_ROOT=/{print $0}' | sed -e 's/TAO_ROOT=//'"
                          }

def log_compiler_tool_versions():
    tools = "Compiler_Tools: "
    for toolname in compiler_Tools: # add in the list of compiler tools
        version_lines = getoutput( compiler_Tools[ toolname ] ).split( "\n" )
        version = version_lines[0].replace("'","")
        version = version.replace("\"","")
        tools +=  toolname + " --> " + version + " // "
    return tools[0:-4]

def log_environment( git_tag):
    environment = "Environment: pp_version --> " + git_tag + " // "
    for variable in environment_variables: # add in the list of compiler tools
        version_lines = getoutput( environment_variables[ variable ] ).split( "\n" )
        version = version_lines[0].replace("'","")
        version = version.replace("\"","")
        environment +=  variable + " --> " + version + " // "
    return environment[0:-4]
    
def main ( args ):
    if len( args ) != 2:
        print "Usage: %s <GIT_TAG>" % args[ 0 ]
        sys.exit( -1 )
    git_tag = args[ 1 ]
    tag_message = log_compiler_tool_versions() + " //// " + log_environment(git_tag)
    print tag_message
    
if __name__=="__main__":
    main( sys.argv )
