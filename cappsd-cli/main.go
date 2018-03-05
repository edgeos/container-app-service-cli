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
		"Location of Cappsd socket.")
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

	timeout := time.Duration(600 * time.Second)
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
		fi, _ := file.Stat()
		defer file.Close()

		var req *http.Request
		uri = "http://unix/application/deploy"

    byteBuf := &bytes.Buffer{}
    mpWriter := multipart.NewWriter(byteBuf)
    _ = mpWriter.WriteField("metadata", `{"Name":"`+*appName+`", "Version":"`+*version+`"}`)
    mpWriter.CreateFormFile("artifact", filepath.Base(*tarFile))
    contentType := mpWriter.FormDataContentType()

    nmulti := byteBuf.Len()
    multi := make([]byte, nmulti)
    _, _ = byteBuf.Read(multi)

    mpWriter.Close()
    nboundary := byteBuf.Len()
    lastBoundary := make([]byte, nboundary)
    _, _ = byteBuf.Read(lastBoundary)
    totalSize := int64(nmulti) + fi.Size() + int64(nboundary)

		rd, wr := io.Pipe()
		defer rd.Close()

		// writing without a reader will deadlock so write in a goroutine
		go func() {
		  defer wr.Close()
		  _, _ = wr.Write(multi)
			buf := make([]byte, 1000000)
			for {
			    n, err := file.Read(buf)
			    if err != nil {
			        break
			    }
			    _, _ = wr.Write(buf[:n])
			}
			_, _ = wr.Write(lastBoundary)
		}()

		req, err = http.NewRequest("POST", uri, rd)
		if err != nil {
			break
		}

		req.Header.Set("Content-Type", contentType)
		req.ContentLength = totalSize

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
		if resp != nil {
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
		} else {
			fmt.Fprintf(os.Stderr, "error: Got null response from cappsd server.\n")
			os.Exit(21)
		}
	}
	os.Exit(0)
}
