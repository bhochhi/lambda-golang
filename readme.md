
- build
```
GOOS=linux go build -o build/main cmd/main.go
```
- zip package
```
zip -jrm build/main.zip build/main
```


- testing from console
 ```
 aws lambda invoke \
    --function-name golangWorld \
    --cli-binary-format raw-in-base64-out \
    --payload '{ "InstanceID":["i-0b3083ff292bb1243" ]}' \
    response.json
```
