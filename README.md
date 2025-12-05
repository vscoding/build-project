# build project

<!-- TOC -->
* [build project](#build-project)
  * [basic variables](#basic-variables)
  * [functions](#functions)
    * [log func](#log-func)
    * [command_exists func](#command_exists-func)
    * [detect ssh port](#detect-ssh-port)
    * [detect os](#detect-os)
    * [date format](#date-format)
  * [build gradle's project](#build-gradles-project)
  * [build maven's project](#build-mavens-project)
  * [build golang's project](#build-golangs-project)
  * [build node's project](#build-nodes-project)
    * [nvm on linux](#nvm-on-linux)
  * [build writerside's project](#build-writersides-project)
  * [docker](#docker)
    * [build docker's image (and push)](#build-dockers-image-and-push)
    * [remove docker's image](#remove-dockers-image)
    * [install docker](#install-docker)
    * [config docker](#config-docker)
  * [develop](#develop)
    * [config maven](#config-maven)
    * [verify nginx configuration](#verify-nginx-configuration)
  * [proxy config](#proxy-config)
    * [bashrc proxy config](#bashrc-proxy-config)
    * [docker daemon proxy config](#docker-daemon-proxy-config)
<!-- TOC -->

## basic variables

> get basic variables

```shell
# export ROOT_URI automatically
source <(curl -sSL https://dev.kubectl.org/init)

# or set manually
# export ROOT_URI=https://dev.kubectl.net
```

## functions

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

### detect ssh port

```shell
ssh_port="$(bash <(curl -sSL $ROOT_URI/func/ssh_port.sh)"

echo "ssh port is $ssh_port"
```

### detect os

```shell
source <(curl -sSL $ROOT_URI/func/detect_os.sh)

echo "$os_name"
```

### date format

```shell
source <(curl -sSL $ROOT_URI/func/date.sh)

echo "$datetime_version"

```

## build gradle's project

build gradle's project by docker

```shell
bash <(curl -sSL $ROOT_URI/gradle/build.sh) \
  -d [build_dir] \
  -c <cache_volume> \
  -i <gradle_image> \
  -x <gradle_command>
```

- `-d`: gradle构建的目录 可为空，默认执行脚本的目录
- `-c`: gradle缓存: 使用`docker volume`挂载
- `-i`: gradle的镜像
- `-x`: gradle的命令
  - e.g. : `gradle clean build -x test`

## build maven's project

build maven's project by docker

```shell
bash <(curl -sSL $ROOT_URI/maven/build.sh) \
  -d [build_dir] \
  -c <cache_volume> \
  -i <maven_image> \
  -s <path/to/settings.xml> \
  -x <maven_command>
```

- `-d`: maven构建的目录 可为空，默认执行脚本的目录
- `-c`: maven缓存
- `-i`: maven镜像
- `-s`: maven `settings.xml` 在本地的路径
- `-x`: maven执行的命令
  - e.g. : `mvn clean install -Dmaven.test.skip=true`

## build golang's project

build golang's project by docker

```shell
bash <(curl -sSL $ROOT_URI/golang/build.sh) \
  -d [build_dir] \
  -c <cache_volume> \
  -i <gradle_image> \
  -x <gradle_command>
```

- `-d`: golang构建的目录 可为空，默认执行脚本的目录
- `-c`: golang缓存: 使用`docker volume`挂载
- `-i`: golang的镜像
- `-x`: golang的命令
  - e.g. : `go build -v -o application`

## build node's project

```shell
bash <(curl -sSL $ROOT_URI/node/build.sh) \
  -d [build_dir] \
  -i <gradle_image> \
  -x <gradle_command>
```

- `-d`: node 构建的目录 可为空，默认执行脚本的目录
- `-i`: node 的镜像
- `-x`: node 的命令
  - e.g. : `npm install --registry=https://registry.npmmirror.com`
  - e.g. : `npm run build`

### nvm on linux

> HOME is /root

install

```shell
bash <(curl -sSL $ROOT_URI/node/nvm/install.sh)
```

uninstall

```shell
bash <(curl -sSL $ROOT_URI/node/nvm/uninstall.sh)
```

## build writerside's project

build writerside's project by docker

```shell
bash <(curl -sSL $ROOT_URI/writerside/build.sh) \
  -d [build_dir] \
  -i <instance>
```

- `-d`: writerside 构建的目录 可为空，默认执行脚本的目录
- `-i`: writerside 的 instance

## docker

### build docker's image (and push)

> by Dockerfile

```shell
bash <(curl -sSL $ROOT_URI/docker/build.sh) \
  -m [multi_platform] \
  -d [build_dir] \
  -f [path/to/Dockerfile] \
  -i <image_name> \
  -v <image_tag> \
  -r <re_tag_flag> \
  -t [new_tag] \
  -p <push_flag>
```

- `-m`: 多平台构建(同时构建amd64和arm64的平台)的选择 `true` | `false` ,默认 `true`
- `-d`: `docker build` 最后指定的路径，如果为空，默认使用 Dockerfile所在的文件路径
- `-f`: `Dockefile` 的路径, 默认的构建基础路径在Dockerfile的路径下
  - 可选的参数, 如果没有, 会寻找执行脚本路径下的 `DOCKERFILE` 或 `Dockerfile` 或 `dockerfile`
- `-i`: 构建的镜像名称
- `-v`: 构建的镜像版本
- `-r`: 对于存在的镜像是否重新tag `true | false`
- `-t`: 对于存在的镜像，重新tag的版本
- `-p`: 是否push到仓库中

[example (build goland' project and push)](https://github.com/svcops/ifconfig/blob/main/build.sh)

### remove docker's image

```shell
bash <(curl -sSL $ROOT_URI/docker/tools/rmi.sh) \
  -i image_name \
  -s strategy

```

- `-i`: 镜像的名称
- `-s`: 删除的策略：默认策略 `contain_latest`
  - `contain_latest` 保留 `latest` 镜像，删除其他镜像
  - `remove_none` 删除 `none` 的镜像
  - `all`: 删除所有镜像

### install docker

**debian系 安装docker**

```shell
bash <(curl -sSL $ROOT_URI/docker/install.sh) SRC
````

- SRC: 源 (`docker` 官方源 / `tsinghua` 清华源 / `aliyun` 阿里云)

**手动安装docker**

```shell
bash <(curl -sSL $ROOT_URI/docker/install-manually/install.sh) $arch $version
````

- `arch`: 系统架构
- `version`: docker版本

### config docker

> config `/etc/docker/daemon.json`

```shell
bash <(curl -sSL $ROOT_URI/docker/config.sh)
```

## develop

### config maven

config maven `settings.xml`

```shell
bash <(curl -sSL $ROOT_URI/maven/config.sh)
```

### verify nginx configuration

验证基于`docker-compose`启动的nginx的配置文件

```shell
source <(curl -sSL $ROOT_URI/nginx/verify_func.sh)
if verify_nginx_configuration nginx path/to/docker-compose.yml; then
  log "verify" "verify success, then start"
else
  log "verify" "verify failed, then edit again"
fi
```

- 方法参数一: service_name
- 方法参数二: compose文件位置，可传递，默认寻找执行脚本目录下的 `docker-compose.yml` 或者 `docker-comopose.yaml`

快速验证

```shell
bash <(curl -sSL $ROOT_URI/nginx/verify.sh) nginx path/to/docker-compose.yml
```

- `nginx` 是 `docker-compose.yaml`中定义的`service`
- 第二个参数 `docker-comopse.yml`的路径，默认会在执行脚本的当前路径下寻找 `docker-compose.yml` 或者 `docker-compose.yaml`

## proxy config

### bashrc proxy config

```shell
bash <(curl -sSL $ROOT_URI/linux/system/bashrc/config_bashrc_proxy.sh) $PROXY_URL $NO_PROXY_CONTENT
```

- `PROXY_URL`: 代理的地址
  - e.g. `http://127.0.0.1:8888`
  - e.g. `socks5h://127.0.0.1:1080`
- `NO_PROXY_CONTENT`: 不需要代理地址
  - e.g. `.local,localhost,127.0.0.1,192.168.*.*,10.0.0.0/8`

### docker daemon proxy config

```shell
bash <(curl -sSL $ROOT_URI/docker/config_daemon_proxy.sh) $PROXY_URL $NO_PROXY_CONTENT
```

- `PROXY_URL`: 代理的地址
  - e.g. `http://127.0.0.1:8888`
  - e.g. `socks5h://127.0.0.1:1080`
- `NO_PROXY_CONTENT`: 不需要代理地址
  - e.g. `localhost,127.0.0.1,docker-registry.somecorporation.com`
