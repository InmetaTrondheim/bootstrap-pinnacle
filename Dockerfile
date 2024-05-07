# FROM mcr.microsoft.com/azure-cli
# RUN az extension add --name azure-devops
# RUN apk update
# RUN apk add opentofu
# #ENTRYPOINT tofu
# WORKDIR /app
# COPY tfwrapper.sh /usr/local/bin/tfwrapper
# RUN chmod +x /usr/local/bin/tfwrapper
# ENTRYPOINT ["tfwrapper"]
# CMD ["--help"]
#
RUN nuget pack -NoDefaultExcludes
RUN dotnet new install .\Inmeta.Netcore.Template.1.x.x.nupkg
ENTRYPOINT dotnet new -n $name  Inmeta.Netcore.Template. /output

