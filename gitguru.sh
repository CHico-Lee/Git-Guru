#!/bin/bash
# Author: Chi Ho Lee

# Script to merge multiple branches into the current checkout branch and checkout as a new branch with the concatenates branch name.
# Only support branch name without "__" (double underscore)
# example 1: $ ~/gitguru.sh -b testing IN-1234 IN-3242
# This will merge testing, IN-1234 and IN-3242 together as a new branch name call merge__testing__IN-1234__IN-3242
# example 2: $ ~/gitguru.sh IN-1234 IN-3242 IN-4567
# This will merge IN-1234, IN-3242 and IN-4567 into the current branch as a new branch name call [CurrentBranchName]__IN-1234__IN-3242__IN-4567

# Font Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ $# == 0 ] || [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
  echo "Usage:"
  echo "  ~/gitguru.sh {-u|-l}"
  echo "  ~/gitguru.sh [-b] <BranchName>..."
  echo "  ~/gitguru.sh <BranchName>..."
  echo "Merge multiple branches into the current checkout branch and checkout "
  echo "as a new branch with the concatenates branch name."
  echo "Enter multiple branch names separate by space."
  echo "  -b, --base-branch         Checkout the first branch as a base branch"
  echo "                              and prefix branch name with 'merge__'"
  echo "  -u, --up                  Update all merged branchs"
  echo "  -l, --log                 Display pretty git log graph"
  echo "  -h, --help                Display this help and exit"
  echo ""
  echo "Example 1: $ ~/gitguru.sh -b testing IN-1234 IN-3242"
  echo "           This will merge testing, IN-1234 and IN-3242 together"
  echo "           as a new branch name call merge__testing__IN-1234__IN-3242 ."
  echo "Example 2: $ ~/gitguru.sh IN-1234 IN-3242 IN-4567"
  echo "           This will merge IN-1234, IN-3242 and IN-4567 into the current branch "
  echo "           as a new branch name call [CurrentBranchName]__IN-1234__IN-3242__IN-4567 ."
  exit
fi

# variables
args_list=( "$@" )
args_index=0
args_size=$#
return_array=()
first_arg=$1
base_branch_name=""

created_branches=()

# Function section
split_branch_names() {
  delimiter=__
  s=$1$delimiter
  return_array=()
  while [[ $s ]]; do
    return_array+=( "${s%%"$delimiter"*}" )
    s=${s#*"$delimiter"}
  done
}

is_contains_branch_name() {
    split_branch_names $1
    [[ " ${return_array[@]} " =~ " $2 " ]]
}

# Pre condition: Define $args_index, $args_size, $args_list
merge_all_branches() {
  created_branches=()
  
  for (( i=$args_index; i<$args_size; i++ )); do
    target_branch="${args_list[$i]}"

    test_merge_rslt="$(git merge origin/$target_branch --no-commit --no-ff 2>&1)"
    git merge --abort

    if [[ "$test_merge_rslt" == *"Automatic merge went well"* ]]; then
      # Create base branch prefix with merge-
      if [ $i == $args_index ] && [ "$first_arg" == "-b" ]; then
        base_branch_rslt="$(git branch merge__$base_branch_name 2>&1)"
        git checkout "merge__$base_branch_name"
        if [[ "$base_branch_rslt" == *"already exists"* ]]; then
          # Start updating existing base branch.
          base_merge_rslt="$(git merge origin/$base_branch_name 2>&1)"
          if [[ "$base_merge_rslt" == *"CONFLICT"* ]]; then
             echo "$base_merge_rslt"
             echo -e "${RED}Update merge__$base_branch_name failed due to conflict.${NC}"
          fi
        else
          created_branches+=( "merge__$base_branch_name" )
        fi
      fi

      curr_branch_name="$(git rev-parse --abbrev-ref HEAD 2>&1)"
      # if checkouted branch dont have ticket name include, checkout another one.
      if ! is_contains_branch_name $curr_branch_name $target_branch ; then
        new_branch_rslt="$(git branch ${curr_branch_name}__${target_branch} 2>&1)"
        git checkout "${curr_branch_name}__${target_branch}"
        # If branch contains target branch name, make sure branch is up-to-date with prev merged branch. 
        if [[ "$new_branch_rslt" == *"already exists"* ]]; then
          # Start updating existing branch, only when branch_name is matched to origin.
          new_merge_rslt="$(git merge ${curr_branch_name} 2>&1)"
          if [[ "$new_merge_rslt" == *"CONFLICT"* ]]; then
            echo "$new_merge_rslt"
            echo -e "${RED}Update ${curr_branch_name}__${target_branch} failed due to conflict.${NC}"
          fi
        else
          created_branches+=( "${curr_branch_name}__${target_branch}" )
        fi
      fi
      git merge origin/"$target_branch"

      curr_branch_name="$(git rev-parse --abbrev-ref HEAD 2>&1)"
      echo -e "${GREEN}Merged $target_branch into $curr_branch_name.${NC}"

    elif [[ "$test_merge_rslt" == *"CONFLICT"* ]]; then
      echo "$test_merge_rslt"
      echo -e "${RED}Merging $target_branch failed due to conflict.${NC}"

    else
      echo -e "${YELLOW}No merge changes with $target_branch.${NC}"
      echo "$test_merge_rslt"
    fi

  done
}

remove_created_branches() {
  curr_branch_name="$(git rev-parse --abbrev-ref HEAD 2>&1)"
  for i in "${created_branches[@]}"; do
    if [[ ! $curr_branch_name == "$i" ]]; then
      echo -e "${BLUE}Deleting local branch $i.${NC}"
      git branch -d "$i"
    fi
  done
}

# Execution Begin #

# Display pretty git log graph 
if [ "$1" == "-l" ] || [ "$1" == "--log" ]; then
  git log --graph --pretty=format:'%C(yellow)%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %Cblue<%an>%Creset' --abbrev-commit
  exit
fi

# Fetch origin bracnhes first.
git fetch

# Handle update
if [ "$1" == "-u" ] || [ "$1" == "--up" ]; then
  curr_branch_name="$(git rev-parse --abbrev-ref HEAD 2>&1)"
  curr_branch_name=${curr_branch_name#"merge__"}
  split_branch_names $curr_branch_name

  # Reset args variables for merging function
  args_list=()
  args_index=0
  args_size=${#return_array[@]}

  for i in "${return_array[@]}"; do
    args_list+=( "$i" )
  done

fi

# Checkout base branch
if [ "$1" == "-b" ] || [ "$1" == "--base-branch" ]; then
  git checkout "$2"
  git up
  args_index=2
  base_branch_name="$2"
fi

# Start Merging branches
merge_all_branches

remove_created_branches