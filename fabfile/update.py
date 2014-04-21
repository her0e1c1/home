from fabric.api import *


@task(default=True)
def update():
    """pull github and buid sphinx.
    """
    require("github_dir")
    for d in env.github_dir:
        with lcd(d):
            print("git pull %s" % d)
            local("git pull")

    require("sphinx_dir")
    for src, dst in env.sphinx_dir:
        local("sphinx-build -b html %s %s" % (src, dst))  

@task
def push():
    """push github repository.
    """
    require("github_dir")
    for d in env.github_dir:
        # if nothing to commit, stop to push
        print("git auto commit and push %s" % d)
        with lcd(d):
            local("git add .")
            with quiet():
                rv = local("git ci -m 'auto commit by fabric'")
            if rv.succeeded:
                local("git push")
            else:
                print("stop to push")
                
@task
def ansible(limit=None):
    """run playbook """
    require("ansible")
    env.ansible["limit"] = limit
    cmd = "ansible-playbook -i {hosts} {playbook}"
    if limit is not None:
        cmd += " --limit {limit}"
    local(cmd.format(**env.ansible))