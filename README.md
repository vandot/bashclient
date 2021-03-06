# Bash HTTP Client

CLI HTTP "client" and a bash HTTP "library" for sending HTTP requests.

This is a basic HTTP client. Codes 200, 301 and 302 redirection and all 4XX and 5XX error codes are supported. _SSL is not supported._ Only text file download is supported.

## Requirements

  1. `bash`, 3 or later

## Installation

```sh
Git clone or copy paste bashclient.sh
```

## Example usage

You can use bashclient as a library and source it inside your script, or as a CLI tool with arguments.

```sh
$ ./bashclient.sh -u http://google.com
$ ./bashclient.sh -s google.com -p /#q=bashclient.sh+github
$ ./bashclient.sh -u http://freegeoip.net/json > response.json
```
When sourcing inside script call get_http function with URL as a argument or set SERVER and URLPATH variables inside your script. URLPATH must be set with a leading /.