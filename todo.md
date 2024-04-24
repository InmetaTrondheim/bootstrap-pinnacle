

##TODO:
### bootstrap:
- [ ] pack bootstrap up in docker, and run via pull request pipeline
- [ ] generalize for github and gitlab bootstrapping
- [ ] consider making templating more flexible via running script on top of template repo
---   ie: use blank repo as template, and run `dotnet new` or `npm init` in it()
---   alternatively: use proper backend template, and run commands to "layer" pipeline files specific to platform into the repo
### infra:
- [ ] create terrafrom file with frontend app, backend app, and db
- [ ] set up secrets in the deploy piplene(IE, db connection string) 
- [ ] can this be auto applied at creation? 
- [ ] this is dependent on build artifacts from frontend and backend being available
### pipeline:
- [ ] run pipelines by default on frontend and backend
