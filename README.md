# build project

## Setup

export `ROOT_URI` automatically

```shell
# export ROOT_URI automatically
source <(curl -sSL https://dev.kubectl.org/init)
```

## Examples

### log func

```shell
source <(curl -sSL $ROOT_URI/func/log.sh)

log "hello" "world"
log_info "hello" "world"
log_warn "hello" "world"
log_error "hello" "world"
```

### command_exists func

```shell
source <(curl -sSL $ROOT_URI/func/command_exists.sh)

if command_exists docker ; then
    echo "command docker exists"
fi
```
