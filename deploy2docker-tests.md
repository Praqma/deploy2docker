## Test `deployer.sh`:
Right, so we have everything in place. We can do some tests locally (on the dev/docker server itself), to see if `deployer.sh` does it's thing. 

Test 1-4 are checking the functionality with fake task file. Test 5 is the actual deployment with a real (example) repository.

### Test 1:
On a separate terminal on the dev server, I create a dummy **task file** with the following entry. The script should detect it as invalid, and will not use it. 

```
[deployer@dev deploy2docker]$ echo "https://gitlab.com/witline/wordpress/blogdemo.wbitt.com 1234567" > deployer.tasks.d/blogdemo.wbitt.com
```

The control loop will detect a task file, and will try to work on it, only to realize that the URL it sees is not really a git repository, and will throw it away.


```
[deployer@dev ~]$ tail -f  /home/deploy2docker/logs/deployer.log 
2020-08-08_21:48:01 Starting script /home/deploy2docker/deployer.sh
2020-08-08_21:48:01 Finished running the script /home/deploy2docker/deployer.sh

2020-08-08_22:06:01 Starting script /home/deploy2docker/deployer.sh
2020-08-08_22:06:01 =====>  Processing deployment task file: /home/deploy2docker/deployer.tasks.d/blogdemo.wbitt.com
2020-08-08_22:06:01 Syntax is NOT OK for GIT repository URL: 'https://gitlab.com/witline/wordpress/blogdemo.wbitt.com'
2020-08-08_22:06:01 The URL 'https://gitlab.com/witline/wordpress/blogdemo.wbitt.com' needs to be a git repo - (URL ending in .git)! Exiting ...
2020-08-08_22:06:01 Recording 'CONFIG-ERROR' in: /home/deploy2docker/logs/deployer.done.log ...
2020-08-08_22:06:01 Removing deployment task file: /home/deploy2docker/deployer.tasks.d/blogdemo.wbitt.com ...
2020-08-08_22:06:01 Skipping /home/deploy2docker/deployer.tasks.d/blogdemo.wbitt.com ...
2020-08-08_22:06:01 Finished running the script /home/deploy2docker/deployer.sh
. . . 
2020-08-08_22:07:01 Starting script /home/deploy2docker/deployer.sh
2020-08-08_22:07:01 Finished running the script /home/deploy2docker/deployer.sh
. . . 
```

Check the done file. It should have a new line in it.

```
[deployer@dev ~]$ tail -f  /home/deploy2docker/logs/deployer.done.log

2020-08-08_22:06:01 	 https://gitlab.com/witline/wordpress/blogdemo.wbitt.com 	 1234567 	 CONFIG-ERROR
```

So, I have tested it by removing the hash altogether, or entering non-alphanumeric characters in the hash, etc, and the script detects the problem and throws away the task file. I will skip repeating those tests in this guide. 


### Test 2:
Lets test a success case. I will setup a new task file provide the correct git URL, but with some random hash. Note that the actual hash of the upstream git repository could be anything, so for a test, it is ok to just provide any random hash. This should result in `deployer.sh` detecting a difference in hash of local directory and the (supposed) hash of upstream, and should re-deploy the docker-compose application.

Lets create a new task file manually. 

```
[deployer@dev deploy2docker]$ echo "https://gitlab.com/witline/wordpress/blogdemo.wbitt.com.git 7654321" > deployer.tasks.d/blogdemo.wbitt.com
```

Lets check the log files:

```
[deployer@dev ~]$ tail -f  /home/deploy2docker/logs/deployer.log 

2020-08-08_22:13:01 Starting script /home/deploy2docker/deployer.sh
2020-08-08_22:13:01 Finished running the script /home/deploy2docker/deployer.sh
2020-08-08_22:14:01 Starting script /home/deploy2docker/deployer.sh
2020-08-08_22:14:01 =====>  Processing deployment task file: /home/deploy2docker/deployer.tasks.d/blogdemo.wbitt.com
2020-08-08_22:14:01 Syntax is OK for GIT repository URL: 'https://gitlab.com/witline/wordpress/blogdemo.wbitt.com.git'
2020-08-08_22:14:01 Syntax is OK for GIT repository hash: '7654321'
2020-08-08_22:14:01 Local directory hash '95617ee' , and  upstream repo hash '7654321' - are different. Changes need to be applied.
2020-08-08_22:14:01 Performing 'git pull' inside: /home/containers-runtime/blogdemo.wbitt.com ...
2020-08-08_22:14:03 Stopping docker-compose application - blogdemo.wbitt.com ...
2020-08-08_22:14:06 Removing older containers - blogdemo.wbitt.com ...
2020-08-08_22:14:07 Starting docker-compose application - blogdemo.wbitt.com ...
2020-08-08_22:14:07 This may take a while depending on the size/design of the application.
2020-08-08_22:14:09 Application in the repo 'blogdemo.wbitt.com' has been started successfully.
2020-08-08_22:14:09 Recording 'GIT-PULL-DOCKER-SUCCESS' in: /home/deploy2docker/logs/deployer.done.log ...
2020-08-08_22:14:09 Removing deployment task file: /home/deploy2docker/deployer.tasks.d/blogdemo.wbitt.com ...
2020-08-08_22:14:09 Finished running the script /home/deploy2docker/deployer.sh
. . . 
2020-08-08_22:15:01 Starting script /home/deploy2docker/deployer.sh
2020-08-08_22:15:01 Finished running the script /home/deploy2docker/deployer.sh
```

Check the "done" file:

```
[deployer@dev deploy2docker]$ tail logs/deployer.done.log 
2020-08-08_22:06:01 	 https://gitlab.com/witline/wordpress/blogdemo.wbitt.com 	 1234567 	 CONFIG-ERROR

2020-08-08_22:14:09 	 https://gitlab.com/witline/wordpress/blogdemo.wbitt.com.git 	 7654321 	 GIT-PULL-DOCKER-SUCCESS
```
Good!


Check `docker ps`, which should show that this container has been restarted recently:

```
[deployer@dev deploy2docker]$ docker ps
CONTAINER ID        IMAGE                                  COMMAND                  CREATED             STATUS              PORTS                                      NAMES
c3c316bd23d5        blogdemowbittcom_blogdemo.wbitt.com    "/usr/local/bin/word…"   2 minutes ago       Up 2 minutes        80/tcp                                     blogdemowbittcom_blogdemo.wbitt.com_1
0933d1e59bda        privatecoachingno_privatecoaching.no   "/usr/local/bin/word…"   10 days ago         Up 10 days          80/tcp                                     privatecoachingno_privatecoaching.no_1
f02d338766b5        mysql:5.7                              "docker-entrypoint.s…"   10 days ago         Up 10 days          3306/tcp, 33060/tcp                        mysql_mysql.local_1
3cdc6a6b8aaa        traefik:1.7                            "/traefik"               10 days ago         Up 10 days          0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp   00-traefik-proxy_traefik_1
[deployer@dev deploy2docker]$ 
```


### Test 3:

Lets see what happens if the hash of upstream and hash of local directory are same.

```
[deployer@dev deploy2docker]$ echo "https://gitlab.com/witline/wordpress/blogdemo.wbitt.com.git 95617ee" > deployer.tasks.d/blogdemo.wbitt.com
```

Check the logs:
```
[deployer@dev ~]$ tail -f  /home/deploy2docker/logs/deployer.log 
2020-08-08_22:17:01 Starting script /home/deploy2docker/deployer.sh
2020-08-08_22:17:01 Finished running the script /home/deploy2docker/deployer.sh
. . . 
2020-08-08_22:18:01 Starting script /home/deploy2docker/deployer.sh
2020-08-08_22:18:01 =====>  Processing deployment task file: /home/deploy2docker/deployer.tasks.d/blogdemo.wbitt.com
2020-08-08_22:18:01 Syntax is OK for GIT repository URL: 'https://gitlab.com/witline/wordpress/blogdemo.wbitt.com.git'
2020-08-08_22:18:01 Syntax is OK for GIT repository hash: '95617ee'
2020-08-08_22:18:01 Directory hash '95617ee' , and  Upstream Repo hash '95617ee' - are same. Nothing to do.
2020-08-08_22:18:01 Recording 'NOOP' in: /home/deploy2docker/logs/deployer.done.log ...
2020-08-08_22:18:01 Removing deployment task file: /home/deploy2docker/deployer.tasks.d/blogdemo.wbitt.com ...
2020-08-08_22:18:01 Finished running the script /home/deploy2docker/deployer.sh
. . . 
```

Check the "done" file:

```
[deployer@dev deploy2docker]$ tail logs/deployer.done.log 
2020-08-08_22:06:01 	 https://gitlab.com/witline/wordpress/blogdemo.wbitt.com 	 1234567 	 CONFIG-ERROR
2020-08-08_22:14:09 	 https://gitlab.com/witline/wordpress/blogdemo.wbitt.com.git 	 7654321 	 GIT-PULL-DOCKER-SUCCESS
2020-08-08_22:18:01 	 https://gitlab.com/witline/wordpress/blogdemo.wbitt.com.git 	 95617ee 	 NOOP
[deployer@dev deploy2docker]$ 
```


### Test 4:
I will remove this "blogedemo" docker-compose application directory completely from `/home/containers-runtime/`, while keeping the related "secrets" and the "data" directories in-tact. This should result in `deployer.sh` detecting that the repository does not exist inside `/home/containers-runtime/`, and it should try to pull/clone it and then start it up.

In kubernetes terms, this is equivalent to submitting/applying a "deployment" using `kubectl`.

First, we stop it and remove it's run-time directory:

```
[deployer@dev deploy2docker]$ cd /home/containers-runtime/blogdemo.wbitt.com/

[deployer@dev blogdemo.wbitt.com]$ docker-compose -f docker-compose.server.yml stop
Stopping blogdemowbittcom_blogdemo.wbitt.com_1 ... done

[deployer@dev blogdemo.wbitt.com]$ docker-compose -f docker-compose.server.yml rm -f
Going to remove blogdemowbittcom_blogdemo.wbitt.com_1
Removing blogdemowbittcom_blogdemo.wbitt.com_1 ... done

[deployer@dev blogdemo.wbitt.com]$ cd ..

[deployer@dev containers-runtime]$ rm -fr /home/containers-runtime/blogdemo.wbitt.com 
[deployer@dev containers-runtime]$ 
```
Note: I have not deleted secrets and the persistent data directories for it. In kubernetes terms, I have only deleted the deployment, and **not** deleted related secret and PV/PVC.


Check `docker ps`:
```
[deployer@dev containers-runtime]$ docker ps
CONTAINER ID        IMAGE                                  COMMAND                  CREATED             STATUS              PORTS                                      NAMES
0933d1e59bda        privatecoachingno_privatecoaching.no   "/usr/local/bin/word…"   10 days ago         Up 10 days          80/tcp                                     privatecoachingno_privatecoaching.no_1
f02d338766b5        mysql:5.7                              "docker-entrypoint.s…"   10 days ago         Up 10 days          3306/tcp, 33060/tcp                        mysql_mysql.local_1
3cdc6a6b8aaa        traefik:1.7                            "/traefik"               10 days ago         Up 10 days          0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp   00-traefik-proxy_traefik_1
[deployer@dev containers-runtime]$ 
```

OK. So the blogdemo container/compose-application is not there anymore. Good!


Lets create a task file, and see if `deployer.sh` can detect that it is absent, and can clone it and start it.


```
[deployer@dev deploy2docker]$ echo "https://gitlab.com/witline/wordpress/blogdemo.wbitt.com.git 95617ee" > deployer.tasks.d/blogdemo.wbitt.com
```

Check the logs:

```
[deployer@dev ~]$ tail -f  /home/deploy2docker/logs/deployer.log 
2020-08-08_22:31:01 Starting script /home/deploy2docker/deployer.sh
2020-08-08_22:31:01 Finished running the script /home/deploy2docker/deployer.sh
. . . 
2020-08-08_22:32:01 Starting script /home/deploy2docker/deployer.sh
2020-08-08_22:32:01 =====>  Processing deployment task file: /home/deploy2docker/deployer.tasks.d/blogdemo.wbitt.com
2020-08-08_22:32:01 Syntax is OK for GIT repository URL: 'https://gitlab.com/witline/wordpress/blogdemo.wbitt.com.git'
2020-08-08_22:32:01 Syntax is OK for GIT repository hash: '95617ee'
2020-08-08_22:32:01 Local directory '/home/containers-runtime/blogdemo.wbitt.com' does not exist - OR - is not a 'git' directory.
2020-08-08_22:32:01 Attempting to clone the repo 'https://gitlab.com/witline/wordpress/blogdemo.wbitt.com.git' into '/home/containers-runtime/blogdemo.wbitt.com' ...
2020-08-08_22:32:01 Creating directory /home/containers-runtime/blogdemo.wbitt.com ...
2020-08-08_22:32:01 Cloning repo https://gitlab.com/witline/wordpress/blogdemo.wbitt.com.git into /home/containers-runtime/blogdemo.wbitt.com ...
2020-08-08_22:32:03 Starting docker-compose application - blogdemo.wbitt.com ...
2020-08-08_22:32:03 This may take a while depending on the size/design of the application.
2020-08-08_22:32:06 Application in the repo 'blogdemo.wbitt.com' has been started successfully.
2020-08-08_22:32:06 Recording 'GIT-CLONE-DOCKER-SUCCESS' in: /home/deploy2docker/logs/deployer.done.log ...
2020-08-08_22:32:06 Removing deployment task file: /home/deploy2docker/deployer.tasks.d/blogdemo.wbitt.com ...
2020-08-08_22:32:06 Finished running the script /home/deploy2docker/deployer.sh
. . . 
2020-08-08_22:33:01 Starting script /home/deploy2docker/deployer.sh
2020-08-08_22:33:01 Finished running the script /home/deploy2docker/deployer.sh
```

Check the "done" file:
```
[deployer@dev deploy2docker]$ tail logs/deployer.done.log 
2020-08-08_22:06:01 	 https://gitlab.com/witline/wordpress/blogdemo.wbitt.com 	 1234567 	 CONFIG-ERROR
2020-08-08_22:14:09 	 https://gitlab.com/witline/wordpress/blogdemo.wbitt.com.git 	 7654321 	 GIT-PULL-DOCKER-SUCCESS
2020-08-08_22:18:01 	 https://gitlab.com/witline/wordpress/blogdemo.wbitt.com.git 	 95617ee 	 NOOP
2020-08-08_22:32:06 	 https://gitlab.com/witline/wordpress/blogdemo.wbitt.com.git 	 95617ee 	 GIT-CLONE-DOCKER-SUCCESS
[deployer@dev deploy2docker]$ 

```

Check `docker ps`, this blogdemo application should be up:
```
[deployer@dev deploy2docker]$ docker ps
CONTAINER ID        IMAGE                                  COMMAND                  CREATED              STATUS              PORTS                                      NAMES
b8155f4c579b        blogdemowbittcom_blogdemo.wbitt.com    "/usr/local/bin/word…"   About a minute ago   Up About a minute   80/tcp                                     blogdemowbittcom_blogdemo.wbitt.com_1
0933d1e59bda        privatecoachingno_privatecoaching.no   "/usr/local/bin/word…"   10 days ago          Up 10 days          80/tcp                                     privatecoachingno_privatecoaching.no_1
f02d338766b5        mysql:5.7                              "docker-entrypoint.s…"   10 days ago          Up 10 days          3306/tcp, 33060/tcp                        mysql_mysql.local_1
3cdc6a6b8aaa        traefik:1.7                            "/traefik"               10 days ago          Up 10 days          0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp   00-traefik-proxy_traefik_1
[deployer@dev deploy2docker]$ 

```

It works!
