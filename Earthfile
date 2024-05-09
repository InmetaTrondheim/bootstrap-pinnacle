# Earthfile

# Base setup with all necessary dependencies
VERSION 0.8
FROM earthly/earthly:latest
WORKDIR /code
COPY . .

# Build target
build:
    RUN echo running \"BUILD  +build\" 

# Immediate tests target
immediate-tests:
    RUN echo running \"BUILD  +unit\" 
    RUN echo running \"BUILD  +scan-secrets\" 

# Publish target
publish:
    RUN echo running \"BUILD  +scan-secrets\" 

# Comprehensive tests target
comprehensive-tests:
    RUN echo running \"BUILD  +integration-test\"  
    RUN echo running \"BUILD  +e2e-test\"  

# Deployment target
deploy:
    RUN echo running \"BUILD  +deploy\"  

