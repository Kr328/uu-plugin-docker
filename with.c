#define _GNU_SOURCE

#include <fcntl.h>
#include <sched.h>
#include <stdio.h>
#include <unistd.h>

#define NS_PATH "/var/run/scoped-uuplugin/network.ns"

int main(int argc, char **argv) {
    if (argc < 2) {
        printf("Usage: %s prog [args...]", argv[0]);

        return 0;
    }

    int fd = open(NS_PATH, O_RDONLY | O_CLOEXEC);
    if (fd < 0) {
        perror("open(ns)");
        return 1;
    }

    if (setns(fd, CLONE_NEWNET) < 0) {
        perror("setns(NET)");
        return 1;
    }

    int gid = getgid();
    setresgid(gid, gid, gid);
    int uid = getuid();
    setresuid(uid, uid, uid);

    execvp(argv[1], &argv[1]);
    perror("exec");

    return 1;
}
