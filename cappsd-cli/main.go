// Copyright (c) 2017 by General Electric Company. All rights reserved.

// The copyright to the computer software herein is the property of
// General Electric Company. The software may be used and/or copied only
// with the written permission of General Electric Company or in accordance
// with the terms and conditions stipulated in the agreement/contract
// under which the software has been supplied.
package main

import (
	"bytes"
	"context"
	"flag"
	"fmt"
	"io"
	"mime/multipart"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

func main() {

	endpoint := flag.String("endpoint", "", "endpoint to hit: ping, deploy, applications, application, start, restart, stop, status, purge")
	sock := flag.String("sock", "/var/run/cappsd.sock",
		"Location of Cappsd socket. Defaults to /var/run/cappsd.sock")
	id := flag.String("id", "", "Container ID for targeted requests")
	appName := flag.String("app_name", "", "App name")
	version := flag.String("version", "", "App version")
	tarFile := flag.String("tar_file", "", "Path to tar file for app")

	flag.Parse()

	// Check input length
	if len(os.Args) <= 1 {
		flag.Usage()
		os.Exit(11)
	}

	// No endpoint selected
	if *endpoint == "" {
		fmt.Println("No endpoint selected.")
		flag.Usage()
		os.Exit(12)
	}

	timeout := time.Duration(300 * time.Second)
	client := http.Client{
		Timeout: timeout,
		Transport: &http.Transport{
			DialContext: func(_ context.Context, _, _ string) (net.Conn, error) {
				return net.Dial("unix", *sock)
			},
		},
	}

	var uri string
	var resp *http.Response
	var err error
	var reader io.Reader

	switch *endpoint {
	case "ping":
		uri = "http://unix/ping"
		resp, err = client.Get(uri)
	case "applications":
		uri = "http://unix/applications"
		resp, err = client.Get(uri)
	case "application":
		uri = "http://unix/application/" + *id
		resp, err = client.Get(uri)
	case "restart":
		uri = "http://unix/application/restart/" + *id
		resp, err = client.Post(uri, "", reader)
	case "start":
		uri = "http://unix/application/start/" + *id
		resp, err = client.Post(uri, "", reader)
	case "stop":
		uri = "http://unix/application/stop/" + *id
		resp, err = client.Post(uri, "", reader)
	case "status":
		uri = "http://unix/application/status/" + *id
		resp, err = client.Get(uri)
	case "purge":
		uri = "http://unix/application/purge/" + *id
		resp, err = client.Post(uri, "", reader)
	case "deploy":
		var file *os.File
		file, err = os.Open(*tarFile)
		if err != nil {
			fmt.Fprintf(os.Stderr, "error: %s\n", err)
			os.Exit(14)
		}
		defer file.Close()

		var req *http.Request
		uri = "http://unix/application/deploy"
		reqBody := &bytes.Buffer{}
		writer := multipart.NewWriter(reqBody)
		part, err := writer.CreateFormFile("artifact", filepath.Base(*tarFile))
		if err != nil {
			fmt.Fprintf(os.Stderr, "error: %s\n", err)
			os.Exit(15)
		}

		_, err = io.Copy(part, file)
		if err != nil {
			fmt.Fprintf(os.Stderr, "error: %s\n", err)
			os.Exit(16)
		}

		_ = writer.WriteField("metadata", `{"Name":"`+*appName+`", "Version":"`+*version+`"}`)

		err = writer.Close()
		if err != nil {
			fmt.Fprintf(os.Stderr, "error: %s\n", err)
			os.Exit(17)
		}

		req, err = http.NewRequest("POST", uri, reqBody)
		if err != nil {
			break
		}
		req.Header.Set("Content-Type", writer.FormDataContentType())
		resp, err = client.Do(req)

	default:
		fmt.Println("Unknown endpoint")
		flag.Usage()
		os.Exit(13)
	}

	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %s\n", err)
		os.Exit(18)
	} else {
		respBody := &bytes.Buffer{}

		_, err := respBody.ReadFrom(resp.Body)
		if err != nil {
			fmt.Fprintf(os.Stderr, "error: %s\n", err)
			os.Exit(19)
		}

		if resp.StatusCode != 200 {
			fmt.Fprintf(os.Stderr, "HTTP bad Response: %d, %s\n", resp.StatusCode, respBody)
			os.Exit(20)
		}
		resp.Body.Close()
		fmt.Println(respBody)
	}
	os.Exit(0)
}
