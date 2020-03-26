package main

import (
	"fmt"
	"github.com/alphagov/paas-cf/tools/user_emails/emails"
	"github.com/cloudfoundry-community/go-cfclient"
	"github.com/jszwec/csvutil"
	"github.com/xenolf/lego/log"
	"gopkg.in/alecthomas/kingpin.v2"
	"os"
)

var (
	apiEndpoint = kingpin.Flag("api-endpoint", "API endpoint").Default("").Envar("API_ENDPOINT").String()
	apiToken = kingpin.Flag("api-token", "CF OAuth API token").Default("").Envar("API_TOKEN").String()
	critical = kingpin.Flag("critical", "Print the contact list for a critical message").Default("false").Envar("CRITICAL").Bool()
	management = kingpin.Flag("management", "Print the contact list for a message to org management").Default("false").Envar("MANAGEMENT").Bool()
)

type Csv struct {
	Email string `csv:"email"`
}


func main(){
	kingpin.Parse()

	if !apiTokenPresent(apiToken) {
		log.Fatal("no API token provided")
		os.Exit(1)
	}

	if !apiEndpointPresent(apiEndpoint) {
		log.Fatal("no API endpoint provided")
		os.Exit(1)
	}

	client, err := cfclient.NewClient(&cfclient.Config{
		ApiAddress: *apiEndpoint,
		Token:      *apiToken,
	})

	if err != nil {
		log.Fatal(err)
		os.Exit(1)
	}

	addresses := emails.FetchEmails(client, *critical, *management)


	b, err := csvutil.Marshal(addresses)
	if err != nil {
		fmt.Println("error:", err)
	}
	fmt.Println(string(b))
}

func apiEndpointPresent(apiEndpoint *string) bool {
	if apiEndpoint == nil ||*apiEndpoint == "" {
		return false
	}

	return true
}

func apiTokenPresent(apiToken *string) bool {
	if apiToken == nil || *apiToken == "" {
		return false
	}

	return true
}
