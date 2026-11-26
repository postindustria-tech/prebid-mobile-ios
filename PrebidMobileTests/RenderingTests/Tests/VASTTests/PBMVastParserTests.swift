/*   Copyright 2018-2021 Prebid.org, Inc.
 
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
 
  http://www.apache.org/licenses/LICENSE-2.0
 
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
  */

import XCTest

@_spi(PBMInternal) @testable import PrebidMobile

class PBMVastParserTests: XCTestCase {
    
    private var logToFile: LogToFileLock?
    
    override func setUp() {
        self.continueAfterFailure = true
        MockServer.shared.reset()
    }
    
    override func tearDown() {
        logToFile = nil
        MockServer.shared.reset()
        super.tearDown()
    }
    // MARK: - Tests
    
    func testVastParserDidEndElementAd() {

        //Create an ad
        let ad = VastAbstractAd()
        ad.creatives = [VastCreativeAbstract()]
        
        //Set up an VastParser
        let pbmVastParser = VastParser()
        pbmVastParser.parsedResponse = VastResponse()
        pbmVastParser.ad = ad
        pbmVastParser.adAttributes = ["id":"12345"]
        
        //Force the end of an "Ad" element
        pbmVastParser.parser(XMLParser(), didEndElement: "Ad", namespaceURI: nil, qualifiedName:nil)
        
        //The parser's VastResponse should contain the ad we created with an appropriate sequence number.
        XCTAssert(pbmVastParser.parsedResponse!.vastAbstractAds.count == 1)
        XCTAssert(pbmVastParser.parsedResponse!.vastAbstractAds.first as! VastAbstractAd === ad)
        XCTAssert(ad.sequence == 0)
        
        //The parser should tidy up after the Ad tag is done parsing.
        XCTAssert(pbmVastParser.ad == nil)
        XCTAssert(pbmVastParser.inlineAd == nil)
        XCTAssert(pbmVastParser.wrapperAd == nil)
        XCTAssert(pbmVastParser.adAttributes == nil)
    }

    //Confirm we can parse a VAST 3.0 response
    func testVastParserFromFile() {

        guard let xmlData = UtilitiesForTesting.loadFileAsDataFromBundle("vast.3.0.xml") else {
            XCTFail("Could not load video")
            return
        }
        let pbmVastParser = VastParser()
        
        XCTAssertNotNil(pbmVastParser.parseAdsResponse(xmlData))
    }
    
    func testVastParserNoAdsResponseErrorURI() {
        let xmlString = """
        <VAST version="3.0">
            <Error><![CDATA[https://example.com/vast-error]]></Error>
        </VAST>
        """
        let parser = VastParser()
        let response = parser.parseAdsResponse(Data(xmlString.utf8))
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.noAdsResponseURI, "https://example.com/vast-error")
    }
    
    // MARK: - Test Parse Resource
    
    func testParseResourceCreativeCompanionStaticType() {
        
        // Prepare
        let parser = VastParser()
        let creative = VastCreativeCompanionAds()
        
        creative.companions = [VastCreativeCompanionAdsCompanion()]
        parser.currentElementAttributes = ["creativeType" : "test"]
        
        parser.creative = creative
        
        // Run
        parser.parseResource(for: .staticResource)
        
        // Test
        let container = parser.extractCreativeContainer()!
        XCTAssertEqual(container.resourceType, .staticResource)
        XCTAssertEqual(container.staticType, "test")
    }
    
    func testParseResourceCreativeCompanionFrameType() {
        
        // Prepare
        let parser = VastParser()
        let creative = VastCreativeCompanionAds()
        
        creative.companions = [VastCreativeCompanionAdsCompanion()]
        parser.currentElementAttributes = ["creativeType" : "test"]
        
        parser.creative = creative
        
        // Run
        parser.parseResource(for: .iFrameResource)
        
        // Test
        let container = parser.extractCreativeContainer()!
        XCTAssertEqual(container.resourceType, .iFrameResource)
        XCTAssertNil(container.staticType)
    }
    
    func testParseResourceCreativeLinear() {
        
        // Prepare
        let parser = VastParser()
        let creative = VastCreativeLinear()
        
        creative.icons = [VastIcon()]
        
        parser.creative = creative
        
        // Run
        parser.parseResource(for: .staticResource)
        
        // Test
        let container = parser.extractCreativeContainer()!
        XCTAssertEqual(container.resourceType, .staticResource)
    }
    
    func testParseResourceCreativeNonLinearAds() {
        
        // Prepare
        let parser = VastParser()
        let creative = VastCreativeNonLinearAds()
        
        creative.nonLinears = [VastCreativeNonLinearAdsNonLinear()]
        
        parser.creative = creative
        
        // Run
        parser.parseResource(for: .staticResource)
        
        // Test
        let container = parser.extractCreativeContainer()!
        XCTAssertEqual(container.resourceType, .staticResource)
    }
    
    func testParseResourceWithError() {
        
        let logErrorNAContainer = "No applicable container to apply"
        
        // nil creative
        self.checkErrorLog( { parser in
            parser.creative = nil
            parser.parseResource(for: .iFrameResource)
        }, expectedLog: "No applicable creative")

        // not particular creative
        self.checkErrorLog( { parser in
            parser.creative = VastCreativeAbstract()
            parser.parseResource(for: .staticResource)
        }, expectedLog: logErrorNAContainer)

        // Linear
        self.checkErrorLog( { parser in
            parser.creative = VastCreativeLinear()
            parser.parseResource(for: .staticResource)
        }, expectedLog: logErrorNAContainer)
        
        // missmatch between creative and container
        // VastCreativeCompanionAds
        self.checkErrorLog( { parser in
            let creative = VastCreativeCompanionAds()
            
            // The ObjC test put a wrong-typed element here; typed arrays make that unrepresentable, so only the empty case remains.
            creative.companions = []
            
            parser.creative = creative
            
            // Test
            parser.parseResource(for: .staticResource)

            XCTAssertNil(parser.extractCreativeContainer())
        }, expectedLog: logErrorNAContainer)
        
        // missmatch between creative and container
        // VastCreativeLinear
        self.checkErrorLog( { parser in
            let creative = VastCreativeLinear()
            
            creative.icons = []
            
            parser.creative = creative
            
            // Test
            parser.parseResource(for: .staticResource)
            
            XCTAssertNil(parser.extractCreativeContainer())
        }, expectedLog: logErrorNAContainer)
        
        // missmatch between creative and container
        // VastCreativeNonLinearAds
        self.checkErrorLog( { parser in
            let creative = VastCreativeNonLinearAds()
            
            creative.nonLinears = []
            
            parser.creative = creative
            
            // Test
            parser.parseResource(for: .staticResource)
            
            XCTAssertNil(parser.extractCreativeContainer())
        }, expectedLog: logErrorNAContainer)
    }
    
    // MARK: - Test Parse TimeInterval
    
    func testParseTimeInterval() {
        
        // Valid interval
        XCTAssertEqual(VastParser().parseTimeInterval("00:00:00"), 0)
        XCTAssertEqual(VastParser().parseTimeInterval("00:00:30"), 30)
        XCTAssertEqual(VastParser().parseTimeInterval("00:00:60"), 60)
        XCTAssertEqual(VastParser().parseTimeInterval("00:00:61"), 61)
        XCTAssertEqual(VastParser().parseTimeInterval("00:00:99"), 99)
        XCTAssertEqual(VastParser().parseTimeInterval("00:01:00"), 60)
        XCTAssertEqual(VastParser().parseTimeInterval("00:01:60"), 120)
        XCTAssertEqual(VastParser().parseTimeInterval("00:01:61"), 121)
        XCTAssertEqual(VastParser().parseTimeInterval("00:60:00"), 3600)
        XCTAssertEqual(VastParser().parseTimeInterval("00:99:00"), 5940)
        XCTAssertEqual(VastParser().parseTimeInterval("01:00:00"), 3600)
        XCTAssertEqual(VastParser().parseTimeInterval("01:01:00"), 3660)
        XCTAssertEqual(VastParser().parseTimeInterval("01:01:01"), 3661)
        XCTAssertEqual(VastParser().parseTimeInterval("99:99:99"), 362439)
        
        // Strange but also correct
        XCTAssertEqual(VastParser().parseTimeInterval("00:30"), 30)
        XCTAssertEqual(VastParser().parseTimeInterval(":30"), 30)
        XCTAssertEqual(VastParser().parseTimeInterval("30"), 30)
        XCTAssertEqual(VastParser().parseTimeInterval(""), 0)
        XCTAssertEqual(VastParser().parseTimeInterval("0"), 0)

        // Invalid interval
        self.checkErrorLog({parser in
            XCTAssertEqual(parser.parseTimeInterval("00:00:00:30"), 0)
        }, expectedLog: "Unable to parse time string")
    }
    
    // MARK: - Helper Methods
    
    func checkErrorLog(_ parse: (VastParser) -> Void, expectedLog: String, file: StaticString = #file, line: UInt = #line) {
        
        logToFile = .init()
        
        parse(VastParser())
        
        let log = Log.getLogFileAsString() ?? ""
        
        XCTAssertTrue(log.contains(expectedLog), "Log: \"\(log)\" not contains: \"\(expectedLog)\"", file: file, line: line)
    }

    func testParseAdVerificationsInWrapper() {
        let vast = """
        <VAST version="4.2">
          <Ad id="w">
            <Wrapper>
              <AdSystem>wrapper</AdSystem>
              <VASTAdTagURI><![CDATA[https://example.com/vast]]></VASTAdTagURI>
              <AdVerifications>
                <Verification vendor="wrapperVendor">
                  <JavaScriptResource apiFramework="omid"><![CDATA[https://wrapper.example.com/omid.js]]></JavaScriptResource>
                  <VerificationParameters><![CDATA[p=1]]></VerificationParameters>
                </Verification>
              </AdVerifications>
            </Wrapper>
          </Ad>
        </VAST>
        """

        let response = VastParser().parseAdsResponse(vast.data(using: .utf8)!)
        let wrapper = response?.vastAbstractAds.first as? VastWrapperAd
        let resources = wrapper?.verificationParameters.verificationResources

        XCTAssertEqual(resources?.count, 1)
        XCTAssertEqual(resources?.first?.vendorKey, "wrapperVendor")
        XCTAssertEqual(resources?.first?.url, "https://wrapper.example.com/omid.js")
        XCTAssertEqual(resources?.first?.params, "p=1")
    }

    // MARK: - AdVerifications node and its Extension form

    private func verifications(vendor: String) -> String {
        """
        <AdVerifications>
          <Verification vendor="\(vendor)">
            <JavaScriptResource apiFramework="omid"><![CDATA[https://\(vendor).example.com/omid.js]]></JavaScriptResource>
          </Verification>
        </AdVerifications>
        """
    }

    private func verificationsExtension(vendor: String) -> String {
        "<Extension type=\"AdVerifications\">\(verifications(vendor: vendor))</Extension>"
    }

    private func inlineAd(_ children: String) -> String {
        "<Ad><InLine><AdSystem>inline</AdSystem>\(children)</InLine></Ad>"
    }

    private func wrapperAd(_ children: String) -> String {
        "<Ad><Wrapper><AdSystem>wrapper</AdSystem><VASTAdTagURI><![CDATA[https://example.com/vast]]></VASTAdTagURI>\(children)</Wrapper></Ad>"
    }

    // The vendors of the verifications each ad of the document ends up with.
    private func parsedVendors(_ ads: String, file: StaticString = #filePath, line: UInt = #line) -> [[String?]] {
        let vast = "<VAST version=\"4.2\">\(ads)</VAST>"
        guard let response = VastParser().parseAdsResponse(Data(vast.utf8)) else {
            XCTFail("The document is not parsed", file: file, line: line)
            return []
        }

        return response.vastAbstractAds.map { ad in
            let parameters = (ad as? VastInlineAd)?.verificationParameters ?? (ad as? VastWrapperAd)?.verificationParameters
            return parameters?.verificationResources.map(\.vendorKey) ?? []
        }
    }

    func testAdVerificationsNodeWinsOverALaterExtension() {
        let ad = inlineAd(verifications(vendor: "node") + "<Extensions>\(verificationsExtension(vendor: "extension"))</Extensions>")

        XCTAssertEqual(parsedVendors(ad), [["node"]])
    }

    func testAdVerificationsNodeWinsOverAnEarlierExtension() {
        let ad = inlineAd("<Extensions>\(verificationsExtension(vendor: "extension"))</Extensions>" + verifications(vendor: "node"))

        XCTAssertEqual(parsedVendors(ad), [["node"]])
    }

    func testAdVerificationsExtensionIsUsedWithoutTheNode() {
        let ad = inlineAd("<Extensions>\(verificationsExtension(vendor: "extension"))</Extensions>")

        XCTAssertEqual(parsedVendors(ad), [["extension"]])
    }

    func testFirstAdVerificationsExtensionWins() {
        let extensions = verificationsExtension(vendor: "first") + verificationsExtension(vendor: "second")
        let ad = inlineAd("<Extensions>\(extensions)</Extensions>")

        XCTAssertEqual(parsedVendors(ad), [["first"]])
    }

    func testAdVerificationsNodeWinsOverTheExtensionInAWrapper() {
        let ad = wrapperAd(verifications(vendor: "node") + "<Extensions>\(verificationsExtension(vendor: "extension"))</Extensions>")

        XCTAssertEqual(parsedVendors(ad), [["node"]])
    }

    // The choice is made per ad: a node in one ad does not hide the Extension of the next one.
    func testAdVerificationsSourceIsChosenPerAd() {
        let first = inlineAd(verifications(vendor: "node"))
        let second = inlineAd("<Extensions>\(verificationsExtension(vendor: "extension"))</Extensions>")
        let third = wrapperAd("<Extensions>\(verificationsExtension(vendor: "wrapperExtension"))</Extensions>")

        XCTAssertEqual(parsedVendors(first + second + third), [["node"], ["extension"], ["wrapperExtension"]])
    }
}
