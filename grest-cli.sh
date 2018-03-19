#!/bin/bash -e

export PS4='+ [$(basename ${BASH_SOURCE})] [${LINENO}] '
SCRIPT_NAME=$(basename $0)

GRESTRC_FILE="$HOME/.grestrc"
CURL_GET="curl --digest --netrc-file $GRESTRC_FILE -s -X GET"
CURL_PUT="curl --digest --netrc-file $GRESTRC_FILE -s -X PUT"
CURL_POST="curl --digest --netrc-file $GRESTRC_FILE -s -X POST"
CURL_DELETE="curl --digest --netrc-file $GRESTRC_FILE -s -X DELETE"

declare -A CMD_USAGE_MAPPING
declare -A CMD_OPTION_MAPPING
declare -A CMD_FUNCTION_MAPPING

GERRIT_URL=
ENDPOINT_ACCOUNTS=
ENDPOINT_PROJECTS=
ENDPOINT_GROUPS=
ENDPOINT_CONFIG=

ERROR_CODE_GRESTRC_FILE_NOT_FOUND=1
ERROR_CODE_COMMAND_NOT_SUPPORTED=2
ERROR_CODE_UNAUTHORIZED_ACCOUNT_FOUND=3
ERROR_CODE_BATCH_FILE_NOT_FOUND=4
ERROR_CODE_INVALID_OPTIONS_FOUND=5

function log_i() {
    echo -e "Info : $*"
}

function log_e() {
    echo -e "Error: $*"
}

function __analyse_http_code() {
    local _HTTP_CODE=
    local _RET_VALUE=

    _HTTP_CODE=$1
    case "$_HTTP_CODE" in
        2*)
            _RET_VALUE="true"
            ;;
        4*)
            _RET_VALUE="false"
            ;;
    esac

    eval "$_RET_VALUE"
}

function __check_config() {
    local _MACHINES=
    local _INDEX=
    local _CHOICE=
    local _MACHINE=
    local _CANONICAL_URLS=
    local _CLI_CMD=
    local _RES_FILE=
    local _HTTP_CODE=

    if [ ! -f "$GRESTRC_FILE" ]; then
        log_e "file not found: $GRESTRC_FILE"
        return $ERROR_CODE_GRESTRC_FILE_NOT_FOUND
    fi

    _MACHINES=($(awk '/^machine/ {print $2}' "$GRESTRC_FILE"))
    _CANONICAL_URLS=($(awk '/^canonicalurl/ {print $2}' "$GRESTRC_FILE"))
    if [ ${#_MACHINES[@]} -gt 1 ]; then
        echo "As several Gerrit servers are provided, please choose one:"
        _INDEX=0
        for I in ${_MACHINES[@]}; do
            _INDEX=$((_INDEX + 1))
            echo "$_INDEX. $I"
        done
        while true; do
            read -p "Your choice (the index number): " _CHOICE
            if ! echo "$_CHOICE" | grep -qE "[0-9]+"; then
                echo "Unacceptable choice: '$_CHOICE'"
                echo
                continue
            fi

            if [ "$_CHOICE" -ge 1 ] && [ "$_CHOICE" -le "$_INDEX" ]; then
                _INDEX=$((_CHOICE - 1))
                _MACHINE=${_MACHINES[$_INDEX]}
                GERRIT_URL="${_CANONICAL_URLS[$_INDEX]}/a"
                echo
                break
            else
                echo "Unacceptable choice: '$_CHOICE'"
                echo
            fi
        done
    else
        _MACHINE="${_MACHINES[0]}"
        GERRIT_URL="${_CANONICAL_URLS[0]}/a"
    fi

    ENDPOINT_ACCOUNTS="$GERRIT_URL/accounts"
    ENDPOINT_PROJECTS="$GERRIT_URL/projects"
    ENDPOINT_GROUPS="$GERRIT_URL/groups"
    ENDPOINT_CONFIG="$GERRIT_URL/config"

    _RES_FILE="response"
    _CLI_CMD="$CURL_GET -w '%{http_code}' \
        -o $_RES_FILE \
        $ENDPOINT_ACCOUNTS/self"
    _HTTP_CODE=$(eval "$_CLI_CMD")
    rm -f "$_RES_FILE"
    if ! __analyse_http_code "$_HTTP_CODE"; then
        log_e "unauthorized account found in file $GRESTRC_FILE"
        return $ERROR_CODE_UNAUTHORIZED_ACCOUNT_FOUND
    fi

    return 0
}

function __covert_name() {
    echo "$1" | sed "s|/|%2F|g"
}

# Usage of getting revision for branches 
function __print_usage_of_get_branch() {
    cat << EOU
SYNOPSIS
    1. $SCRIPT_NAME get-branch -p <PROJECT> -b <BRANCH>
    2. $SCRIPT_NAME get-branch -f <FILE>

DESCRIPTION
    Gets revision of branch <BRANCH> of project <PROJECT>.

    The 1st format
        Used for checking revision of a single project-branch pair.

    The 2nd format
        Gets revisions using project-branch pairs provided by file <FILE>.
        The Mandatory format for file <FILE>:
            - Each line must contain two fields which represent <PROJECT> and
              <BRANCH>
            - Uses a whitespace to separate fields in each line
        For example, a file <FILE> is composed of following lines.
            release/jenkins master
            devops/ci dev

OPTIONS
    -p|--project <PROJECT>
        Specify project's name.

    -b|--branch <BRANCH>
        Specify branch's name.

    -f|--file <FILE>
        Specify a file which contains info project and branch.

    -h|--help
        Show this usage document.

EXAMPLES
    1. Get revision for branch master of project release/jenkins
       $ $SCRIPT_NAME get-branch -p release/jenkins -b master

    2. Get revisions for project-master combos provided by file combos.batch
       $ $SCRIPT_NAME get-branch -f combos.batch
EOU
}

# Getting revision for branches
function __get_branch() {
    local _SUB_CMD=
    local _ARGS=
    local _PROJECT=
    local _BRANCH=
    local _RES_FILE=
    local _HTTP_CODE=
    local _LEN_MAX_P=
    local _LEN_MAX_B=
    local _TMP_P=
    local _TMP_B=
    local _REV_MAPPING=
    local _RET_VALUE=

    declare -A _REV_MAPPING=

    _SUB_CMD="get-branch"
    _RET_VALUE=0

    if [ $# -eq 0 ]; then
        eval "${CMD_USAGE_MAPPING[$_SUB_CMD]}"
        return $_RET_VALUE
    fi

    _ARGS=$(getopt ${CMD_OPTION_MAPPING[$_SUB_CMD]} -- $@)
    eval set -- "$_ARGS"
    while [ $# -gt 0 ]; do
        case $1 in
            -p|--project)
                _PROJECT=$2
                ;;
            -b|--branch)
                _BRANCH=$2
                ;;
            -f|--file)
                _BATCH_FILE=$2
                if [ ! -f "$PWD/$_BATCH_FILE" ]; then
                    log_e "file not found: $_BATCH_FILE"
                    return $ERROR_CODE_BATCH_FILE_NOT_FOUND
                fi
                ;;
            -h|--help)
                eval "${CMD_USAGE_MAPPING[$_SUB_CMD]}"
                return $_RET_VALUE
                ;;
            --)
                shift
                break
                ;;
        esac
        shift
    done

    if [ -n "$_BATCH_FILE" ]; then
        if [ -n "$_PROJECT" ] || [ -n "$_BRANCH" ]; then
            log_e "option -f|--file is exclusive with options -p|--project" \
                "and -b|--branch"
            return $ERROR_CODE_INVALID_OPTIONS_FOUND
        fi
    else
        if [ -z "$_PROJECT" ] || [ -z "$_BRANCH" ]; then
            log_e "options -p|--project and -b|--project must be provided" \
               " together"
            return $ERROR_CODE_INVALID_OPTIONS_FOUND
        fi
    fi

    if [ -z "$_BATCH_FILE" ]; then
        _BATCH_FILE=$(mktemp -p "/tmp" --suffix ".batch" "combo.XXX")
        echo "$_PROJECT $_BRANCH" > $_BATCH_FILE
    fi

    # Length of word "Project": 7
    # Length of word "Branch": 6
    _LEN_MAX_P=7
    _LEN_MAX_B=6
    while read _PROJECT _BRANCH; do
        log_i "get branch '$_BRANCH' of project: $_PROJECT"

        if [ "${#_PROJECT}" -gt "$_LEN_MAX_P" ]; then
            _LEN_MAX_P=${#_PROJECT}
        fi

        if [ "${#_BRANCH}" -gt "$_LEN_MAX_B" ]; then
            _LEN_MAX_B=${#_BRANCH}
        fi

        _TMP_P=$_PROJECT
        _TMP_B=$_BRANCH
        _PROJECT=$(__covert_name "$_PROJECT")
        _BRANCH=$(__covert_name "$_BRANCH")

        _RES_FILE="response"
        _CLI_CMD="$CURL_GET -w '%{http_code}' \
            -o $_RES_FILE \
            $ENDPOINT_PROJECTS/$_PROJECT/branches/$_BRANCH"
        _HTTP_CODE=$(eval "$_CLI_CMD")
        if __analyse_http_code "$_HTTP_CODE"; then
            log_i "branch found: $_TMP_B"
            _REV_MAPPING["$_TMP_P"]=$(tail -n+2 "$_RES_FILE" | jq -r ".revision")
        else
            export -f log_e
            cat "$_RES_FILE" | xargs -I {} bash -c 'log_e "$@"' _ {}
            _REV_MAPPING["$_TMP_P"]="????"
        fi

        rm -f "$_RES_FILE"
    done < "$_BATCH_FILE"
 
    echo
    printf "%$((_LEN_MAX_P + _LEN_MAX_B + 4 + 40))s\n" "-" | sed "s| |-|g"
    printf "%-${_LEN_MAX_P}s  %-${_LEN_MAX_B}s  %-s\n" \
        "Project" "Branch" "Revision"
    printf "%$((_LEN_MAX_P + _LEN_MAX_B + 4 + 40))s\n" "-" | sed "s| |-|g"
    while read _PROJECT _BRANCH; do
        printf "%-${_LEN_MAX_P}s  %-${_LEN_MAX_B}s  %-s\n" \
            "$_PROJECT" "$_BRANCH" "${_REV_MAPPING[$_PROJECT]}"
    done < "$_BATCH_FILE"
    printf "%$((_LEN_MAX_P + _LEN_MAX_B + 4 + 40))s\n" "-" | sed "s| |-|g"

    if [[ "$_BATCH_FILE" =~ /tmp/combo.*batch ]]; then
        rm -f "$_BATCH_FILE"
    fi
}

function init_command_context() {
    CMD_USAGE_MAPPING["get-branch"]="__print_usage_of_get_branch"

    CMD_OPTION_MAPPING["get-branch"]="-o p:b:f:h\
        -l project:,branch:,file:,help"

    CMD_FUNCTION_MAPPING["get-branch"]="__get_branch"
}

function enable_verbose_mode() {
    set -x
}

function __print_cli_usage() {
    cat << EOU
Usage: $SCRIPT_NAME [-v] <SUB_COMMAND> [<args>]

A CLI tool which implements customized functions using Gerrit REST API.
1. get-branch
   Gets revision value according to a project-branch combination.

To show usage of a <SUB_COMMAND>, use following command:
   $SCRIPT_NAME help <SUB_COMMAND>
   $SCRIPT_NAME <SUB_COMMAND> --help

Options:
   -v|--verbose     Verbose mode with full execution trace
   -h|--help        Print usage of this CLI tool
EOU
}

function run_cli() {
    local _SUB_CMD=
    local _FOUND=
    local _RET_VALUE=

    _FOUND="false"
    _RET_VALUE=0

    VERBOSE_MODE="false"
    while true; do
        case "$1" in
            -h|--help)
                __print_cli_usage
                return $_RET_VALUE
                ;;
            -v|--verbose)
                VERBOSE_MODE="true"
                shift
                ;;
            *)
                break
                ;;
        esac
    done

    eval "$VERBOSE_MODE" && enable_verbose_mode

    _SUB_CMD="$1"
    if [[ -z "$_SUB_CMD" ]]; then
        __print_cli_usage
    elif [[ "$_SUB_CMD" == "--help" ]]; then
        __print_cli_usage
    else
        for I in ${!CMD_OPTION_MAPPING[@]}; do
            if [[ "$_SUB_CMD" = $I ]]; then
                _FOUND="true"
                break
            fi
        done

        if eval "$_FOUND"; then
            if __check_config; then
                shift
                eval ${CMD_FUNCTION_MAPPING["$_SUB_CMD"]} $*
            else
                _RET_VALUE=$?
            fi
        else
            if [[ "$_SUB_CMD" == "help" ]]; then
                shift
                _SUB_CMD="$1"

                _FOUND="false"
                for I in ${!CMD_OPTION_MAPPING[@]}; do
                    if [[ "$_SUB_CMD" = $I ]]; then
                        _FOUND="true"
                        break
                    fi
                done

                if eval "$_FOUND"; then
                    eval ${CMD_USAGE_MAPPING[$_SUB_CMD]}
                else
                    if [[ -z "$_SUB_CMD" ]]; then
                        __print_cli_usage
                    else
                        _RET_VALUE=$ERROR_CODE_COMMAND_NOT_SUPPORTED
                        log_e "unsupported sub-command: '$_SUB_CMD'"
                    fi
                fi
            else
                _RET_VALUE=$ERROR_CODE_COMMAND_NOT_SUPPORTED
                log_e "unsupported sub-command: '$_SUB_CMD'"
            fi
        fi
    fi

    return $_RET_VALUE
}

init_command_context && run_cli $@

# vim: set shiftwidth=4 tabstop=4 expandtab
