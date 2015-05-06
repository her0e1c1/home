alias -g L="| less -SR"
alias -g G='| grep'
alias -g X='| xargs'
alias -g N1='1>/dev/null'
alias -g N2='2>/dev/null'
alias -g N21='2>&1'
alias -g PP="| perl $PERL_OPTION -aplE"
alias -g P0="| perl $PERL_OPTION -an0lE"
alias -g P="| perl $PERL_OPTION -anlE"
alias -g PD='| perl -nlE "system \$_"'

alias -s {gz,tgz,zip,lzh,bz2,tbz,Z,tar,arj,xz}=extract
