// Copyright (c) 2017 by General Electric Company. All rights reserved.

// The copyright to the computer software herein is the property of
// General Electric Company. The software may be used and/or copied only
// with the written permission of General Electric Company or in accordance
// with the terms and conditions stipulated in the agreement/contract
// under which the software has been supplied.

node {

    stage ("SCM Checkout") {
        checkout scm
    }
    
    stage ("Clean Existing Images") {
        sh '''
            make clean ARCH=amd64
            make clean ARCH=arm
        '''
    }

    stage ("Build amd64") {
        sh '''
            make build
            make image
        '''
    }

    stage ("Test (amd64)") {
        sh ''' make test clean-tests '''
    } 

    stage ("Scan") {
        sh '''
            make scan
        '''
    }

    stage ("Clean Existing Images") {
        sh '''
           make clean
        '''
    }

}
