package cmd
import (
	"github.com/spf13/cobra"
)

var createCmd = &cobra.Command{
	Use:   "create",
	Short: "Create a certificate",
	Run: func(cmd *cobra.Command, args []string) {
		createCert()
	},
}

func init() {
	rootCmd.AddCommand(createCmd)

	// set flags
	createCmd.Flags().StringVarP(&hostname, "hostname", "H", "", "The fully qualified hostname.")
	createCmd.Flags().StringVarP(&outputDir, "output-dir", "O", "", "The directory to output to. Defaults to working directory.")
	createCmd.Flags().StringVarP(&outputFormat, "format", "F", "pem", "The keyfile formant to output. [pem, p12]")
	createCmd.Flags().StringVarP(&password, "password", "P", "", "The password to protect pkcs12 (p12) certificates (optional)")
	createCmd.Flags().StringVarP(&altNames, "alt-names", "", "", "The requested Subject Alternative Names, in a comma-delimited list")
	createCmd.Flags().StringVarP(&ipSans, "ip-sans", "", "", "The requested IP Subject Alternative Names, in a comma-delimited list")
	createCmd.Flags().StringVarP(&uriSans, "uri-sans", "", "", "The requested URI Subject Alternative Names, in a comma-delimited list. (ALTHA: Not tested)")
	createCmd.Flags().BoolVarP(&force, "force", "-f", false, "Overwrite if the file already exists")

	// require
	createCmd.MarkFlagRequired("hostname")
}

func createCert() {
	cert, err := bmcert.CreateCertificate()
	if err != nil {
		printErrorExit(err, 1)
	}

	err = bmcert.WriteCert(cert)
	if err != nil {
		printErrorExit(err, 1)
	}
}
