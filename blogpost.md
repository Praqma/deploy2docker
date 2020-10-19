# deploy2docker - A toolset to deploy docker-compose apps to a plain docker-compose server

This mainly a CI helper / orchestrator for docker. The idea is to mimic kubernetes in terms of major components when you are not using Kubernetes for any reason. This tool tries to bring the **"running state"** of your docker-server to your **"desired-state"** , specified in your `docker-compose.yml` file - all using a CI pipeline - thus a **"deployer"**. 

## Why?/Inspiration:
I understand that Kubernetes is on the rise. It is the most favored platform for deploying containerized applications for last five years, and everyone is either migrating, or eager to migrate their infrastructure to Kubernetes. So where does docker-compose fit? Well, Kubernetes may be extremely popular, but entry point to Kubernetes is a bit hard. Also, for anyone trying to dockerize an application, or just trying a container image to see how it works, and how few containers (micro-services) would work together to solve a particular problem, **docker-compose** is the easiest tool to use. Also, many people have dockerized their applications, but they are not ready for Kubernetes yet. Some of them may have just one small server, which they use as docker host and manually run their applications - as docker-compose apps - on that server. For those people, ability to bring up all the docker-compose apps at the system boot time, and ability to use git+CI pipelines to deploy their code automatically on their docker host(s) is a huge benefit.

I was in this situation about two years ago, and it inspired me to develop this tool-set. (For those who are wondering, I **did not** want to use terraform, ansible or any configuration management system to do this. Those tools make this a very complex problem. So, **no.**) 

In late 2018, I helped a friend of mine to dockerize his applications. These applications (before dockerization) used to be deployed on Linux VMs using traditional system administration methods and tools. Some of these applications were wordpress based websites, and some were code which his team wrote in different programming languages. I helped him deploy the new dockerized applications on individual docker servers. That is when I developed some tools to help automate many aspects of the deployment. 

These tools were:
* Automatic start-up of all compose applications at system boot time, *by pulling latest changes from respective git repositories*. - **docker-compose-apps.sh**
* Automatic deployment from git using CI, without any need to manually log on to the server over ssh and restart any the docker-compose applications. - **deployer**

## Use case:
Suppose you want to deploy a docker-compose application on your docker server. The application could be a simple HTML based website, or a JavaScript application, or wordpress website, etc. You also want to be able to automatically deploy any (future) changes made in your application to be deployed to your docker server, through a CI pipeline. This is the use-case for these tools.


## Assumptions: 
This tools is opinionated and is designed for specific situations. It assumes the following:

* You are relatively small team/company, with shoe-string budget. i.e. You have one or **few** servers in your **"infrastructure"**.
* You have not migrated your applications to Kubernetes because you/your team does not have enough Kubernetes skills yet, or you cannot afford (financially) a Kubernetes cluster provided by various cloud providers.
* You have dockerized apps running on a **single** (and plain) docker host/server. *Not Docker Swarm*
* In case you have distributed multiple (dockerized) apps over multiple docker hosts/servers, each docker host is an independent docker host. There is no shared container network, nor any other clustering technology in place.
* You are running these dockerized apps using **docker-compose**.
* You are the only one managing this/these servers, and the deployment of all dockerized apps; **Or,** you may be a very small team, who are in agreement on how to handle these servers, and how to deploy apps on these servers.
* You have a **single** git repositories location (git-hub/lab/bucket/your-own/etc) for all the software you are developing. This is true for all the close-source software you / your team may be developing. You will need to create a **Git Token** (with limited read-only access to your repositories) to be used by CI system of your choice, to pull the application code from your private git repositories. You will also use this git token from the docker server to pull the git repository to the docker server. If you are deploying code from open-source repositories, then this does not apply.
* Connected to previous assumption, you are able to setup/save the same git token as "git credentials" under the home directory of user `deployer`. This means you trust the people in the team, who will have either access to this user, or people with `sudo` access. To be on the safe side, the git token has only **"read-repository"** access/permissions.
* The **master branch** of all your individual repositories **always contain code that is ready to deploy**. All other code being developed/tested/etc is in other branches.
* You are willing to keep secrets of various docker-compose apps in a central location on the docker host, such as: `/home/containers-secrets/<repository-name>/<filename>.env`, and you are OK with sharing the secrets with your (small) team, or with some people from that small team.
* All docker-compose applications will build their own images, so there is no need to pre-build images, or access private container registries.
* And finally, you have SSH access to the docker server, as `root`.


## How does it work?
Well, first you prepare the docker host with the tools from this repository. i.e. clone this (deploy2docker) repository in `/home/deploy2docker/` directory on your docker host, setup correct ownership and permissions, and setup the required `cron` job.

After that, for each application you want to deploy through CI/CD, you setup it's components in necessary directories on the docker host. For example, for any given docker-compose based application:
* the run-time code will be stored under: `/home/containers-runtime/<repository-name>/` (this is what is cloned/pulled from the related git repository) 
* the secrets would be stored as files under `/home/containers-secrets/<repository-name>/<filename>.env`
* the persistent data is stored under `/home/containers-data/<repository-name>/`
* the `docker-compose.yml` file of your application uses above locations for storing persistent data and loading secrets.

Then, test-deploy the application manually. 

When everything works, you automate it's deployment by adding a `.gitlab-ci.yml` to it's project directory, using code from the  [gitlab-ci.yml.example](gitlab-ci.yml.example) file included in this repository.

Once a `docker-compose` application is deployed, we can use a control script `deployer.sh`, which - in collaboration with `cron` - works as a control loop and watches for incoming tasks. As soon, as CI system connected to a repository sends a special **"task file"** to the docker system, the control script `deployer.sh` picks up this task file, and works on that task. i.e. Apply any changes detected in the related git repository, and restart the related docker-compose application.

### Here is how it works / work-flow:

```
                               [Pull changes from related git repo]-->[restart container]
                                          ^
[CI server]-->                            |
              |                      [deployer.sh] ---->-----
          [internet]                     ^                   |
               |                         |                [wait 1 minute]
             [put task-file]     [pick task file]           |
                |                    ^                 [check tasks directory]
                V                    |                      |
             [ Tasks  directory on docker server ] ---<-----     
```

This blog-post is just an excerpt of the detailed guide available here: [https://github.com/Praqma/deploy2docker/blob/master/README.md](https://github.com/Praqma/deploy2docker/blob/master/README.md). Please this link to learn how to setup and use this tool-set.

# Conclusion:
`deploy2docker` is a set of tools, which makes your life very easy; especially, when - for whatever reason - kubernetes is not an option, you are forced to manage docker-compose applications on docker host, and you don't want to be the meatware-CI (human-CI) for yourself, or your development team. 

I hope you enjoy using these tools as much as I enjoyed developing them, and using them! I have complete peace of mind since I deployed these two tools on my docker servers. I believe they can be used safely by others in similar situations.
