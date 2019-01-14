# Running Ruby on Rails on AWS Lambda and API Gateway by Serverless Framework

This sample code helps get you started with a simple Rails web api deployed on AWS Lambda and API Gateway by Serverless Framework.

Try Ruby on Rails on AWS Lambda and API Gateway by Serverless Framework: https://nihemak.hatenablog.com/entry/2019/01/15/020222

__Resources that referred to__

serverless-sinatra-sample: https://github.com/aws-samples/serverless-sinatra-sample

Building an API with Ruby and the Serverless Framework: https://serverless.com/blog/api-ruby-serverless-framework/

Run Rails on AWS Lambda (Japanese): https://medium.com/ruffnote/aws-lambda%E3%81%A7rails%E3%82%92%E5%8B%95%E3%81%8B%E3%81%99-1770e58771d6

# Getting Started

Build an environment to AWS.

```bash
$ ./setup.sh
```

If you want to change a gem, edit the Gemfile and execute the following to get a new Gemfile.lock.

```
$ docker run -v `pwd`:`pwd` -w `pwd` -it lambci/lambda:build-ruby2.5 bundle install --no-deployment
```
