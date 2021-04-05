#!/bin/bash
clear
#Source folder for CloudSim Automation and CloudSim Plus Automation (they are just in different branches).
#Set this directory to an empty string to force download the jars from GitHub.
AUTOMATION_SOURCES="$HOME/Documents/doutorado/projects/cloudsim-plus-automation"
CLOUDSIM_AUTOMATION_VERSION="0.4.0"
CLOUDSIMPLUS_AUTOMATION_VERSION="6.2.0"

#The directory where the jar files are built.
JARS_DIR="$AUTOMATION_SOURCES/target/"
if [ $AUTOMATION_SOURCES == "" ]; then
    JARS_DIR=""
fi

manual() {
    echo "This script creates and runs a simulation scenario from a YML file in CloudSim and/or CloudSim Plus."
    echo "The scripts uses the jar files from CloudSim Automation and CloudSim Plus Automation projects"
    echo "to automate the creation and execution of simulation scenarios in both frameworks."
    echo "It tries to execute the jar files inside the Automation projects from the directory"
    echo "defined by the JAR_DIRS variable in the script."
    echo "If such jars are not found in such a dir, it tries to download them from GitHub."
    
    echo -e "\nUsage: $0 [SimulationScenarioYmlFile] [Framework]"
    echo -e "\tSimulationScenarioYmlFile: path for a YML file containing the simulation scenario to be built and run"
    echo -e "\t\tIf omitted, default files defined inside the script will be loaded"
    echo -e "\tFramework: the framework to run the cloud simulation, either cloudsim or cloudsimplus"
    exit -1
}

#Download CloudSim Automation or CloudSim Plus Automation from GitHub.
#Params: 
#   $1=project (CloudSimAutomation or cloudsim-plus-automation)
#   $2=jar_version
download_jar () {
    local project=$1
    local jar_version=$2
    local jar_name="$project-$jar_version-with-dependencies.jar"
    local jar_url="https://github.com/manoelcampos/cloudsim-plus-automation/releases/download/v$jar_version/$jar_name"

    if ! test -f "$jar_name"; then
        if test -f "$JARS_DIR$jar_name"; then
            jar_name="$JARS_DIR$jar_name"
        else
            echo -e "\nDownloading $project v$jar_version"
            curl -OL "$jar_url"
        fi   
    fi   
    
    return 0
}

#Try to build CloudSim Automation and CloudSim Plus Automation jars
#if the AUTOMATION_SOURCES is defined.
#Otherwise, try to download the jars from GitHub.
#Params: 
#   $1=project (CloudSimAutomation or cloudsim-plus-automation)
#   $2=jar_version
#   $3=Git branch name for the project to build
try_build_automation_projects(){
    local project=$1
    local jar_version=$2
    local branch=$3

    local dir=`pwd`
    if ! test -d  "$AUTOMATION_SOURCES"; then
        download_jar $project, $jar_version
    else
        cd "$AUTOMATION_SOURCES"
        git checkout $branch > /dev/null && mvn install | grep "Building CloudSim"

        #Leaves just the jar built with the dependencies
        find "$AUTOMATION_SOURCES/target/" | grep -E '.*\d\.jar' | xargs rm
        
        cd "$dir"    
    fi

    return 0
}

#Execute the Simulation Scenario from the YAML file using the jar files
#of CloudSim Automation and CloudSim Plus Automation.
#Params: 
#   $1=project (CloudSimAutomation or cloudsim-plus-automation)
#   $2=jar_version
#   $3=yaml_scenario_file
exec_jar () {
    local project=$1
    local jar_version=$2
    local yaml_scenario_file=$3
    local jar_name="$project-$jar_version-with-dependencies.jar"

    if ! test -f "$jar_name"; then
        if test -f "$JARS_DIR$jar_name"; then
            jar_name="$JARS_DIR$jar_name"
        fi   
    fi   

    java -jar "$jar_name" "$yaml_scenario_file" -s > /tmp/output.log

    if test -f "results.csv"; then
       cat /tmp/output.log | tail -n1 >> results.csv
    else
       cat /tmp/output.log | tail -n2 >> results.csv
    fi
    
    return 0
}

# -------------------------------------------- Start execution --------------------------------------------

if [[ $1 == "-h" || $1 == "-H" || $1 == "--help" || $1 == "--h" || $1 == "/h" ]]; then
    manual
fi

rm -f results.csv

#if the first parameter is an existing YML file, uses that one to run the experiments
if  test -f "$1"; then
   files=$1
#otherwise, loads some YML files defined by a prefix name
else
   prefixName="scenario4."
   files=()
   for i in {1..7}; do
       files+=("$prefixName$i.yml")
   done
   echo "Scenario files: ${files[@]}"
fi

rm -rf "$AUTOMATION_SOURCES/target"
try_build_automation_projects "CloudSimAutomation" $CLOUDSIM_AUTOMATION_VERSION "cloudsim-version"
try_build_automation_projects "cloudsim-plus-automation" $CLOUDSIMPLUS_AUTOMATION_VERSION "master"

for file in "${files[@]}"
do
    if [[ ($1 == "cloudsim" || $2 == "cloudsim") && $# > 0 && $file == $1 ]]; then
        echo "Building and running simulation scenario in CloudSim      from file $file"
        exec_jar "CloudSimAutomation" $CLOUDSIM_AUTOMATION_VERSION $file
    fi

    if [[ $1 == "cloudsimplus" || $2 == "cloudsimplus" || $file == $1 || $# == 0 ]]; then
        echo "Building and running simulation scenario in CloudSim Plus from file $file"
        exec_jar "cloudsim-plus-automation" $CLOUDSIMPLUS_AUTOMATION_VERSION $file
    fi
done 

echo ""
cat results.csv
echo ""
