# docker alias
# 以下のコマンドで、バックアップしたvolumeをマウントできる
# docker run -d -v "$name":/var/lib/mysql mysql 
docker-backup() {
    local data=$1 dir=$2
    docker run --rm --volumes-from "$data" -v $(pwd):/backup busybox sh -c "cd $dir && tar cvf /backup/backup.tar ."
}

docker-restore() {
    local name=$1 backup=$2
    docker volume create --name "$name"
    docker run --rm -v "$name:/volume" -v `pwd`:/backup centos tar xvf "/backup/$backup" -C /volume
}

docker-volume-exists() {
    local volume=$1
    if ! docker volume inspect $1 >/dev/null 2>&1; then
        echo "$1 volume doesn't exist"
        return 1
    fi
}

docker-volume-copy() {
    docker_volume_exists $1 || return 1
    [ $# -eq 2 ] || return 1
    local src=$1 dst=$2
    echo "copy $src $dst"
    docker volume create --name "$dst"
    # -Tは、既存のディレクトリにコピー(GNU)
    docker run --rm -v "$src":/src -v "$dst":/dst centos sh -c "cp -r /src -T /dst"
}

docker-volume-mount() {
    local name=$1 dest=/volume
    docker volume inspect $name
    echo "mount $name $dest"
    docker run --rm -itv "$name:$dest" --workdir "$dest" busybox sh
}

docker-volume-remove() {
    for volume in $@; do
        echo "remove $volume volume"
        docker volume rm $volume
    done
}

docker-process-exists() {
    if ! docker inspect $1 >/dev/null 2>&1; then
        echo "$1 process doesn't exist"
        return 1
    fi
}

docker-process-remove() {
    for p in `docker ps -q`; do
        docker rm -f $p
    done
}

docker-cp() {
    local src=$1  # container
    local dir=$2
    local dst=$3
    docker volume create --name "$dst"
    # -Tは、既存のディレクトリにコピー(GNU)
    docker run --rm --volumes-from "$src" -v "$dst":/backup centos sh -c "cp -r $dir -T /backup"
}

docker-run() { 
    if [ $# -eq 0 ]; then
        docker images
    else
        local name=$1; shift
        local cmd=/bin/bash
        [ $# -ne 0 ] && cmd=$@
        sh -c "docker run --rm -v /Users/mbp:/Users/mbp -w /Users/mbp --detach-keys ctrl-q,q -it $name $cmd"
    fi
}
alias dr=docker-run

docker-volume-help() {
    echo "docker_volume              show volumes"
    echo "docker_volume NAME         enter NAME volume"
    echo "docker_volume SRC DST      copy volume SRC to DST"
    echo "docker_volume -r [NAME...] remove volumes"
}

docker-volume() {
    local rflag=false
    while getopts rh OPT; do
        case $OPT in
            r) rflag=true;;
            h) docker_volume_help; return 0;;
        esac
    done
    shift $((OPTIND - 1))
    if $rflag; then
        docker_volume_remove $@
    elif [ $# -eq 0 ]; then
        docker volume ls
    else
        docker_volume_exists $1 || return 1
        if [ $# -eq 2 ]; then
            docker_volume_copy $1 $2
        else
            docker_volume_mount $1
        fi
    fi
}
alias dv=docker-volume

docker-exec-help() {
    echo "docker_exec               show process"
    echo "docker_exec NAME          enter NAME process"
    echo "docker_exec NAME [CMD...] enter NAME process and run CMD"
    echo "docker_exec -r [NAME...]  remove processes"
}

docker-exec() {
    local rflag=false
    while getopts rh OPT; do
        case $OPT in
            r) rflag=true;;
            h) docker-exec-help; return 0;;
        esac
    done
    shift $((OPTIND - 1))
    if $rflag; then
        docker-volume-remove $@
    elif [ $# -eq 0 ]; then
        docker ps
    else
        local name=$1; shift
        if [ $# -ne 0 ]; then
            # $@はかなり特殊な変数(配列っぽい動きする。そのため他の変数に代入できないっぽい)
            docker exec -it --detach-keys ctrl-q,q $name $@
        else
            docker exec -it --detach-keys ctrl-q,q $name /bin/bash
        fi
    fi
}
alias de=docker-exec
alias dei="docker exec -i"

docker-compose-update() {
    local file=docker-compose.yml
    local project=docker
    local down=false
    while getopts df:p: OPT; do
        case $OPT in
            d) down=true;;
            f) file=$OPTARG;;
            p) project=$OPTARG;;
        esac
    done
    shift $((OPTIND - 1))

    docker-compose -f $file -p $project down -v
    $down && return 0
    docker-compose -f $file -p $project up -d
}

docker-rm-all() { docker rm -f `docker ps -qa`}

docker-rename-image() { docker tag $1 $2; docker rmi $1 }

# 1ファイルを指定して、ホスト側で書き換えたのをうわ書き
docker-edit() {
    local name=$1;
    local p=$2;
    local base=`basename $p`
    local temp="`mktemp`_$base"
    local dest="$name:$p"
    docker cp $dest $temp
    emacsclient -t $temp
    docker cp $temp $dest
}

docker-sync-help() {
    echo "docker-sync NAME SRC [watchmedo options]"
}

# docker run のタイミングでsyncもできるようにするか(指定したディレクトリを監視するみたいな)
# または、cp cpを2回繰り返す! (または docker-sync name /path ./host_side)
# host側のイベントを取りにいけない...
docker-sync () {
    local name=$1; shift
    local src=$1; shift
    local sync=`basename $src`
    local trim=`perl -E '\$_=\$ARGV[0]; s#/*\$## and say' $src`
    if ! docker exec $name test -d $sync; then
        echo "copy $sync on host"
        docker exec $name cp -r $src $sync
    fi
    if docker exec $name test -d $sync; then
        if [ -d "$sync" ]; then
           echo "start sync ..."
           watchmedo shell-command -R "$sync" -c "docker exec $name rsync -avz $sync/ $trim" $@
        else
            echo "You can't sync on `pwd`. Go to $sync on host"
        fi
    else
        echo "$sync dir is not found on docker."
    fi
}

docker-commit () {
    local name=$1; shift;
    local repo=$1; shift;
    if [ $# -ge 3 ]; then
        if [ -n `docker images -q $repo` ]; then
            docker exec $name $@ && docker commit $name $repo
        else
            echo "No repositry $repo"
        fi
    fi
}

docker-compose-all() {
    docker-compose `perl -E 'say map {" -f \$_"} reverse <docker-compose*.yml>'` $@
}
