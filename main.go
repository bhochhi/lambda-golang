package main

import (
	"context"
	"fmt"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/config"
)

type Instance struct {
	InstanceIDs []string `json:"InstanceID"`
}

func init() {
	_, err := config.LoadDefaultConfig(context.TODO(), config.WithRegion("us-east-1"))
	if err != nil {
		panic("configuration error, " + err.Error())
	}

}

func HandleRequest(instances Instance) ([]string, error) {

	// result, err := client.DescribeInstances(context.TODO(), &ec2.DescribeInstancesInput{
	// 	InstanceIds: instances.InstanceIDs,
	// })
	// if err != nil {
	// 	return []string{}, err
	// }

	var status []string
	// for _, r := range result.Reservations {
	// 	for _, i := range r.Instances {
	// 		status = append(status, fmt.Sprintf("InstanceID: %v State: %v", *i.InstanceId, i.State.Name))
	// 	}

	// 	fmt.Println("")
	// }

	status = append(status, fmt.Sprintf("key: %v value: %v", "This is golang", "will need db connect"))

	return status, nil
}

func main() {
	lambda.Start(HandleRequest)
}
