# GREST-CLI
A CLI tool used to interact with Gerrit server via REST API.

## Background
- Although Gerrit server provides a Web UI to support various operations, such as creation and deletion of projects and branches, it's just more convenient and efficient by using commands to achieve the same purpose sometimes.
- As Gerrit provides a powerful set of REST API, this makes it possible to use commands to get lots of operation done.

## Designing
A framework featured with high extensibility is used to design the implementation for this CLI tool.

#### 1. Principles of the Framework

- Every function is treated as a separate sub-command so that there is no interference exists.
- Every function has its own option list, usage document and implementation details.
- An unified entry controls the execution of each function.

## Configuration

#### 1. Set up config file .grestrc

- In order to get following **four required** piece of information for script **grest-cli.sh**, you need to create a config file named **.grestrc** under path **$HOME**.
  1) Machine name of the Gerrit server
  2) Login name of your account
  3) HTTP password of your account
  4) Canonical URL of the Gerrit server
- Here is an example of config file **.grestrc**.
```
# Gerritro server
machine sh-gerritro.sdesigns.com
login blankliu
password L+C4rSUtH54ysefgDefgOfO6EXh48d43TqzBb/EQzA
canonicalurl http://sh-gerritro.sdesigns.com:8080

# A fake server
machine fake.sdesigns.com
login blankliu
password L+C4rSUtH54ysefgDefgOfO6EXh48d43TqzBb/EQzA
canonicalurl http://fake.sdesigns.com:8080
```

> NOTES:
> 1. The format of this file is borrowed from configuration of file [.netrc](https://www.gnu.org/software/inetutils/manual/html_node/The-_002enetrc-file.html).
> 2. Lines start with character '#' are treated as comments.
> 3. A server must be composed of four fields **machine**, **login**, **password** and **canonicalurl**, which have to be put in order.
> 4. The field password is the **HTTP Password** of your Gerrit account. (Settings -> HTTP Password -> Generate Password)
> 5. Specifying multiple servers in this file is supported by separating them into different blocks. One block stands for one Gerrit server.
> 6. When multiple servers are provided, you will be asked to choose one each time you run this CLI tool.

#### 2. Download script grest-cli.sh

```shell
mkdir $HOME/.bin
curl -Lo $HOME/.bin/grest-cli.sh https://raw.githubusercontent.com/blankliu/GREST-CLI/master/grest-cli.sh
chmod a+x $HOME/.bin/grest-cli.sh
```

#### 3. Put script grest-cli.sh into System path

- In order to use script **grest-cli.sh** anywhere within your Shell terminal, placing it into System path is required.

```shell
sudo ln -s $HOME/.bin/grest-cli.sh /usr/bin/grest-cli.sh
```

## How to Extend Script grest-cli.sh

#### Supposes you want to implement a sub-command '*create-branch*', which creates branches for projects, here are the steps to implement it.

- Appends a new item into array **CMD_USAGE_MAPPING** within function **init_command_context**

```shell
# Uses string 'create-branch' as index
# String '__print_usage_of_create_branch' is the name of a new Shell function
CMD_USAGE_MAPPING["create-branch"]="__print_usage_of_create_branch"
```

- Appends a new item into array **CMD_OPTION_MAPPING** within function **init_command_context**

```shell
# Uses string 'create-branch' as index

# Creates options according to your own requirement of how to pass input for getting revisions
# Refers to usage of Shell command 'getopt' for how options are analyzed by 'getopt'
CMD_OPTION_MAPPING["create-branch"]="-o p:b:r:f:h -l project:,branch:,revision:,file:,help"
```

- Appends a new item into array **CMD_FUNCTION_MAPPING** within function **init_command_context**

```shell
# Uses string 'create-branch' as index
# String '__create_branch' is the name of a new Shell function
CMD_FUNCTION_MAPPING["create-branch"]="__create_branch"
```

- Implements two new Shell functions **__print_usage_of_create_branch** and **__create_branch**
> NOTE:
> 1. Shell function **__print_usage_of_create_branch**
>    * It shows how to use sub-command 'create-branch' with script **grest-cli.sh**.
>    * You could refer to function **__print_usage_of_get_branch** for implementation.
> 2. Shell Function **__create_branch**
>    * It implements the work of creating branches for projects.
>    * You could refer to function **__get_branch** for implementation.

- Complements information of sub-command 'get-branch' within function **__print_cli_usage**

## How to Use

#### 1. Show all sub-commands implemented in this CLI tool

```shell
grest-cli.sh --help
```

#### 2. Show usage of a sub-command

- Takes sub-command 'get-branch' as an example, there are two ways to show its usage

```shell
grest-cli.sh help get-branch
grest-cli.sh get-branch --help
```
