
#cdの後にls実行
cdls(){
	if [ ${#1} -eq 0 ]; then
	   cd && ls
	else
       \cd "$*" && ls -G
	fi
}

#emacsのデーモン再起動
function restart_emacs(){
    emacsclient -e "(kill-emacs)";
    emacs --daemon
}

function kill_emacs(){
	emacsclient -e "(kill-emacs)";
}

#圧縮ファイルを名前だけで展開
function extract() {
  case $1 in
    *.tar.gz|*.tgz) tar xzvf $1;;
    *.tar.xz) tar Jxvf $1;;
    *.zip) unzip $1;;
    *.lzh) lha e $1;;
    *.tar.bz2|*.tbz) tar xjvf $1;;
    *.tar.Z) tar zxvf $1;;
    *.gz) gzip -dc $1;;
    *.bz2) bzip2 -dc $1;;
    *.Z) uncompress $1;;
    *.tar) tar xvf $1;;
    *.arj) unarj $1;;
  esac
}

zshaddhistory(){
    local line=${1%%$'\n'}
    local cmd=${line%% *}

    [[ ${#line} -ge 4
       && ${cmd} != (l[sal])
       && ${cmd} != (c|cd)
       && ${cmd} != (m|man)
    ]]
}

sphinx_auto_build(){
    OLD_PATH=`pwd`;
    for p in ${(s/:/)SPHINX_PATH};do
        if [ -d $p ];then
            \cd $p;
            echo `pwd`
            if which inotifywait ;then
                while inotifywait -e modify ./**/*.rst;do make html; done &
            fi
       else
            echo "$pは存在しません";
        fi
    done
    \cd $OLD_PATH;
}

function exists { which $1 &> /dev/null }