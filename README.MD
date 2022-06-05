# Running the Code

# Appendix: Funny Adventures with OpenShift Local Containers (Former CodeReady)

After trying to run the container following the Getting Started page, I discovered that it uses `kvm` that gets in conflict with my existing `virtualbox`, so found this [issue](https://askubuntu.com/questions/403591/amd-v-is-being-used-by-another-hypervisor-verr-svm-in-use) and adapted the scripts to my environment so I can switch to `kvm`:

```
#!/bin/bash
/sbin/rmmod vboxnetflt
/sbin/rmmod vboxnetadp
/sbin/rmmod vboxdrv
/sbin/insmod /lib/modules/`uname -r`/kernel/arch/x86/kvm/kvm.ko.zst
/sbin/insmod /lib/modules/`uname -r`/kernel/arch/x86/kvm/kvm-amd.ko.zst
```

 And also back to `virtualbox`:

 ```
 #!/bin/bash
/sbin/rmmod kvm_amd
/sbin/rmmod kvm
/sbin/insmod /usr/lib/modules/`uname -r`/extramodules/vboxdrv.ko.xz
/sbin/insmod /usr/lib/modules/`uname -r`/extramodules/vboxnetadp.ko.xz
/sbin/insmod /usr/lib/modules/`uname -r`/extramodules/vboxnetflt.ko.xz
/sbin/insmod /usr/lib/modules/`uname -r`/kernel/drivers/virt/vboxguest/vboxguest.ko.zst
/sbin/insmod /usr/lib/modules/`uname -r`/kernel/fs/vboxsf/vboxsf.ko.zst
/sbin/rcvboxdrv setup
```

After running it again, got a timeout error. In the meantime, I learned how to run in debug mode

```
crc start --log-level debug 
```

After some research found this source: https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/crc/2.3.0/ and tried the advanced algorithm of trying things out to pick an older version to see if it works. Tested with `1.9.0`. Didn't work.

So I went back to the latest version and it finally worked with (still keeping log if things go wrong):

```
crc start -c 8 -m 16384 --log-level debug
```

After exploring a bit on `2022-06-04`, I realized that I missed one step on installing the Service Mesh, so on `2022-06-05`, I deleted everything to start from a fresh state, then got this:

```
DEBU SSH command results: err: Process exited with status 1, output:  
DEBU Unable to connect to the server: x509: certificate has expired or is not yet valid: current time 2022-06-05T14:01:45Z is after 2022-06-05T03:19:44Z
```

The certificate had expired on the day before -.-

The [troubleshooting page](https://access.redhat.com/documentation/en-us/red_hat_openshift_local/2.3/html/getting_started_guide/troubleshooting_gsg) says that if the certificate is expired it will try to renew it and would just take an extra 5 min on the deploy. SPOILER ALERT: It doesn't try to renew. 

There is another way of working around it by running:

```
crc stop
crc delete
```

On some github issues also found:

```
crc cleanup
```

So running them altogether and... also didn't work


After looking at some issues on repos (with any of them solved by actually solving it but just marked as stale), I found [this one](https://github.com/openshift/okd/issues/1123) where we can see some comments:

>  This issue comes from the upstream OpenShift release that prevents certificates to exist longer than 30 days. We from @code-ready/crc-team have tried to resolve this for a long time, but has been denied

And looks like no one is updating the release

> We have not received a volunteer yet. Lots of people asking about the status. No one stepping up though. I'll make another push beginning of next week.

At this point:

![Desk flipping](https://i.kym-cdn.com/entries/icons/original/000/006/725/Desk_Flip_banner.jpg "Desk Flipping" )

So I went with `minikube`...
