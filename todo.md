

##TODO:
### bootstrapp:
- [ ] set up terraform state for the g. this is dependent on credentials to create a service prinsiple
- [ ] generalize for repo hosts: github, gitlab, other?
- [ ] generalize for cloud runtimes: aws, gcp, kubernets 

### genesis:
- [ ] set up terraform state for the genesis_repo. this is dependent on credentials to create a service prinsiple
- [ ] set up terraform state for the infra repo. this is dependent on credentials to create a service prinsiple
- [ ] set up merge request policies 
- [ ] terraform apply genesis on merge to master
- [ ] allow for regestering of deveopers in the genesis config
- [ ] allow for seecrets injection config via genesis config
- [ ] allow for 3rd service registration(sentry, sonarcube, jira)
- [ ] allow for inmeta service registration, say we hosta a version of sentry, sonarcube, jira, goalerts?


### infra:
- [ ] terraform apply infra on merge to master
- [ ] create terrafrom file with frontend app, backend app, and db
- [ ] set up secrets in the deploy piplene(IE, db connection string) 
- [ ] this is dependent on build artifacts from frontend and backend being available
- [ ] figgure out how to do staging/prod/sandbox seperation and automatin

### pipeline:
- [x] run pipelines by default on frontend and backend
- [ ] should i set up pipeline runner pools?
- [ ] run validation of repo that is not dependent on any file beeing in the repo 
-- [ ] would be somthing like `earthly github.com/user/repo+target`
-- [ ] would check if earhtfile contract is valid
-- [ ] would check if githooks are set up, if not, then set them up
-- [ ] would check if 

