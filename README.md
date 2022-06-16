# Requirements

* System with the following applications installed:
    * minikube
    * istioctl
    * tkn
    * virtual machine (this example will use VirtualBox)

# Setup

Start minikube with (adapt to best suit your machine config):


## Kubernetes Apps Installation

```
minikube start --memory=16384 --cpus=8 --vm-driver=virtualbox 
```

### Install tekton:

Install Tekton pipelines:

```
kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
```

```
tkn hub install task git-clone --version 0.6
tkn hub install task buildah --version 0.3
tkn hub install task kubernetes-actions --version 0.2
```

[Optional] Install tekton dashboard:

```
kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/latest/tekton-dashboard-release.yaml
```

### Install Istio:

```
istioctl install --set profile=demo -y
```

Enable istio automatic injection
```
kubectl label namespace default istio-injection=enabled
```

Install Kiali:

```
kubectl apply --filename https://raw.githubusercontent.com/istio/istio/release-1.14/samples/addons/kiali.yaml
```
You can check deployment status with:
```
kubectl rollout status deployment/kiali -n istio-system
```

Install Prometheus:

```
kubectl apply --filename https://raw.githubusercontent.com/istio/istio/release-1.14/samples/addons/prometheus.yaml
```

## App Setup

Clone this repo:
```
git clone https://github.com/dokawa/blue-green-app.git
```
Change directories:
```
cd blue-green-app
```

### Deploy the Secret
Create a `secrets.yaml` file based on `tekton/secrets.example.yaml` by replacing `username` and `password`. This example is using `DockerHub`, if you are using another registry, changing `tekton.dev/docker-0` annotation and authentication `type` might be necessary.

```
kubectl apply -f secrets.yaml
```

### Deploy Base Resources
```
kubectl apply -f base/
kubectl apply -f tekton/ 
```

### Configure App and Pipeline
You can go to `app/index.html` and change the `--color` attribute to css color names (red, green, blue, etc.)


Change `pipeline_run.yaml` version to v2. You maight also want to change the weights

### Deploy the App

Run:

```
kubectl create -f pipeline_run.yaml
```
This command will trigger the pipeline that will clone the repo, build and push the container and deploy it to the cluster as specified in `pipeline.yaml`

If you installed Tekton Dashboard, you can check the pipeline running:

```
kubectl port-forward -n tekton-pipelines service/tekton-dashboard 9097:9097
```

# Checking the App

Get the app url:
```
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
export INGRESS_HOST=$(kubectl get po -l istio=ingressgateway -n istio-system -o jsonpath='{.items[0].status.hostIP}')
echo $INGRESS_HOST:$INGRESS_PORT
```

Visit the output url and you should see the app

There is also a utility script on the repo that can be run with:

```
./requests.sh [http://]<ip>:<port>
```
E.g. 
```
./request.sh http://192.168.59.100:30955
```
or 
```
./requests.sh 192.168.59.100:30955
```

And should output the following, highlighting the app version that is being fetched:
```
blue;
green;
```



# Inspecting the Deployment

Running Kiali:
```
istioctl dashboard kiali
```


# Appendix: Funny Adventures with OpenShift Local Containers (Former CodeReady)

I'm documenting this as comic relief and as the quote from Alexander Jason, made famous by Adam Savage says:

>The only difference between science and screwing around is when you write it down.

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

After some research found this source: https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/crc/2.3.0/ and tried the advanced algorithm of trying things out on the url to pick an older version to see if it works. Tested with `1.9.0`. Didn't work.

So I went back to the latest version and for some reason it finally worked with:

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

There was supposedly another way of working around it by running:

```
crc stop
crc delete
```

On some github issues also found:

```
crc cleanup
```

So running them altogether and... also didn't work


After looking at some issues on repos (with none of them solved by actually solving it but just marked as stale), I found [this one](https://github.com/openshift/okd/issues/1123) where we can see some comments from mantainers:

>  This issue comes from the upstream OpenShift release that prevents certificates to exist longer than 30 days. We from @code-ready/crc-team have tried to resolve this for a long time, but has been denied

And looks like no one is updating the release

> We have not received a volunteer yet. Lots of people asking about the status. No one stepping up though. I'll make another push beginning of next week.

At this point I was like:

![Desk flipping](https://i.kym-cdn.com/entries/icons/original/000/006/725/Desk_Flip_banner.jpg "Desk Flipping" )

So I went with `minikube`...
