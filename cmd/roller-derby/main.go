// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

// package main is the entrypoint.
package main

import (
	"fmt"

	"go.yaml.in/yaml/v4"
)

type RollerDerby struct {
	Name string
	Team string
}

func main() {
	data := RollerDerby{
		Name: "Jane Doe",
		Team: "The Rollers",
	}

	m, err := yaml.Marshal(data)
	if err != nil {
		fmt.Println("Error marshaling data:", err)
		return
	}

	fmt.Println(string(m))
}
