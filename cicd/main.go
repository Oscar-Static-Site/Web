package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"

	"dagger.io/dagger"
	"github.com/joho/godotenv"
)

func main() {
	if err := build(context.Background()); err != nil {
		fmt.Println(err)
	}
}

func build(ctx context.Context) error {
	godotenv.Load()
	fmt.Println("Building with Dagger")
	client, err := dagger.Connect(ctx, dagger.WithLogOutput(os.Stderr))
	if err != nil {
		return err
	}

	auth()
	defer client.Close()
	Key := client.SetSecret("awsKey", os.Getenv("AWS_ACCESS_KEY_ID"))
	Secret := client.SetSecret("awsSecret", os.Getenv("AWS_SECRET_ACCESS_KEY"))
	awsRegion := client.SetSecret("awsRegion", os.Getenv("AWS_REGION"))
	dir := client.SetSecret("DIR", os.Getenv("GITHUB_ACTION_PATH"))
	src := client.Host().Directory("$DIR/Web/site")
	hugo := client.Container().
		From("477601539816.dkr.ecr.eu-west-2.amazonaws.com/hugo-oscar-eu:latest")
	hugo = hugo.WithDirectory(".", src).WithWorkdir(".")
	export := "public"
	if _, err := os.Stat(export); errors.Is(err, os.ErrNotExist) {
		err := os.Mkdir(export, os.ModePerm)
		if err != nil {
			log.Println(err)
		}
	}
	hugo = hugo.WithSecretVariable("AWS_ACCESS_KEY_ID", Key)
	hugo = hugo.WithSecretVariable("AWS_SECRET_ACCESS_KEY", Secret)
	hugo = hugo.WithSecretVariable("AWS_DEFAULT_REGION", awsRegion)
	hugo = hugo.WithSecretVariable("DIR", dir)
	hugo = hugo.WithExec([]string{"hugo"})
	hugo = hugo.WithExec([]string{"hugo", "deploy"})
	output := hugo.Directory(export)
	_, err = output.Export(ctx, export)
	if err != nil {
		return err
	}
	return nil
}

func auth() string {
	cmd, err := exec.Command("/bin/sh", "$DIR/cicd/auth.sh").Output()
	if err != nil {
		fmt.Printf("error %s", err)
	}
	output := string(cmd)
	return output
}
