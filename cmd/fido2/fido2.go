package main

import (
	"fmt"
	"log"

	"github.com/williamclot/go-libfido2"
)

func main() {
	locs, err := libfido2.DeviceLocations()
	if err != nil {
		log.Fatal(err)
	}

	for _, loc := range locs {
		fmt.Printf("%+v\n", loc)
	}
}
