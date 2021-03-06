//
//  ProgressSpec.swift
//  Siesta
//
//  Created by Paul on 2015/10/4.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

@testable import Siesta
import Quick
import Nimble
import Nocilla

class ProgressSpec: ResourceSpecBase
    {
    override func resourceSpec(service: () -> Service, _ resource: () -> Resource)
        {
        context("always reaches 1")
            {
            it("on success")
                {
                stubReqest(resource, "GET").andReturn(200)
                let req = resource().load()
                awaitNewData(req)
                expect(req.progress).to(equal(1.0))
                }
            
            it("on server error")
                {
                stubReqest(resource, "GET").andReturn(500)
                let req = resource().load()
                awaitFailure(req)
                expect(req.progress).to(equal(1.0))
                }
            
            it("on connection error")
                {
                stubReqest(resource, "GET").andFailWithError(NSError(domain: "foo", code: 1, userInfo: nil))
                let req = resource().load()
                awaitFailure(req)
                expect(req.progress).to(equal(1.0))
                }
            
            it("on cancellation")
                {
                let reqStub = stubReqest(resource, "GET").andReturn(200).delay()
                let req = resource().load()
                req.cancel()
                expect(req.progress).to(equal(1.0))
                reqStub.go()
                awaitFailure(req, alreadyCompleted: true)
                }
            }
        
        // Exact progress values are subjective, and subject to change. These specs only examine
        // what affects the progress computation.
        
        context("computation")
            {
            var getRequest: Bool!
            var metrics: RequestTransferMetrics!
            var progress: RequestProgress?
            
            beforeEach
                {
                progress = nil
                metrics = RequestTransferMetrics(
                    requestBytesSent: 0,
                    requestBytesTotal: nil,
                    responseBytesReceived: 0,
                    responseBytesTotal: nil)
                setResourceTime(100)
                }
            
            func progressComparison(closure: Void -> Void) -> (before: Double, after: Double)
                {
                progress = progress ?? RequestProgress(isGet: getRequest)
                
                progress!.update(metrics)
                let before = progress!.fractionDone
                
                closure()
                
                progress!.update(metrics)
                let after = progress!.fractionDone
                
                return (before, after)
                }
            
            func expectProgressToIncrease(closure: Void -> Void)
                {
                let result = progressComparison(closure)
                expect(result.after).to(beGreaterThan(result.before))
                }
            
            func expectProgressToRemainUnchanged(closure: Void -> Void)
                {
                let result = progressComparison(closure)
                expect(result.after).to(equal(result.before))
                }
            
            func expectProgressToRemainAlmostUnchanged(closure: Void -> Void)
                {
                let result = progressComparison(closure)
                expect(result.after).to(beCloseTo(result.before, within: 0.01))
                }
            
            context("for request with no body")
                {
                beforeEach { getRequest = true }
                
                it("increases while waiting for request to start")
                    {
                    expectProgressToIncrease
                        { setResourceTime(101) }
                    }
                
                it("is stable when response arrives")
                    {
                    expectProgressToIncrease { setResourceTime(101) }
                    expectProgressToRemainAlmostUnchanged
                        {
                        setResourceTime(1000)
                        metrics.responseBytesReceived = 1
                        metrics.responseBytesTotal = 1000
                        }
                    }
                
                it("tracks download")
                    {
                    metrics.requestBytesSent = 0
                    metrics.requestBytesTotal = 0
                    metrics.responseBytesReceived = 1
                    metrics.responseBytesTotal = 1000
                    expectProgressToIncrease
                        { metrics.responseBytesReceived = 2 }
                    }
                
                it("tracks download even when size is unknown")
                    {
                    metrics.requestBytesSent = 0
                    metrics.requestBytesTotal = 0
                    metrics.responseBytesReceived = 1
                    expectProgressToIncrease
                        { metrics.responseBytesReceived = 2 }
                    }
                
                it("never reaches 1 if response size is unknown")
                    {
                    metrics.requestBytesSent = 0
                    metrics.requestBytesTotal = 0
                    metrics.responseBytesReceived = 1
                    metrics.responseBytesTotal = -1
                    expectProgressToIncrease
                        { metrics.responseBytesReceived = 1000000 }
                    expect(progress?.rawFractionDone).to(beLessThan(1))
                    }

                it("is stable when estimated download size becomes precise")
                    {
                    metrics.requestBytesSent = 0
                    metrics.requestBytesTotal = 0
                    metrics.responseBytesReceived = 10
                    expectProgressToRemainUnchanged
                        { metrics.responseBytesTotal = 20 }
                    }

                it("does not exceed 1 even if bytes downloaded exceed total")
                    {
                    metrics.responseBytesReceived = 10000
                    metrics.responseBytesTotal = 2
                    expectProgressToRemainUnchanged
                        { metrics.responseBytesReceived = 20000 }
                    expect(progress?.rawFractionDone).to(equal(1))
                    }
                }
                
            context("for request with a body")
                {
                beforeEach { getRequest = false }
                
                it("is stable when request starts uploading after a delay")
                    {
                    expectProgressToIncrease { setResourceTime(101) }
                    expectProgressToRemainAlmostUnchanged
                        {
                        setResourceTime(1000)
                        metrics.requestBytesSent = 1
                        metrics.requestBytesTotal = 1000
                        }
                    }
                
                it("tracks upload")
                    {
                    metrics.requestBytesSent = 1
                    metrics.requestBytesTotal = 1000
                    expectProgressToIncrease
                        { metrics.requestBytesSent = 2 }
                    }
                
                it("tracks upload even if upload size is unknown")
                    {
                    metrics.requestBytesSent = 10
                    metrics.requestBytesTotal = -1
                    expectProgressToIncrease
                        { metrics.requestBytesSent = 11 }
                    }
                
                it("is stable when estimated upload size becomes precise")
                    {
                    metrics.requestBytesSent = 10
                    metrics.requestBytesTotal = -1
                    expectProgressToRemainUnchanged
                        { metrics.requestBytesTotal = 100 }
                    }
            
                it("does not track time while uploading")
                    {
                    metrics.requestBytesSent = 1
                    metrics.requestBytesTotal = 1000
                    expectProgressToRemainUnchanged
                        { setResourceTime(120) }
                    }
                
                it("increases while waiting for response after upload")
                    {
                    metrics.requestBytesSent = 1000
                    metrics.requestBytesTotal = 1000
                    expectProgressToIncrease
                        { setResourceTime(110) }
                    }
                
                it("is stable when response arrives")
                    {
                    metrics.requestBytesSent = 1000
                    metrics.requestBytesTotal = 1000
                    expectProgressToIncrease { setResourceTime(110) }
                    expectProgressToRemainAlmostUnchanged
                        {
                        setResourceTime(110)
                        metrics.responseBytesReceived = 1
                        metrics.responseBytesTotal = 1000
                        }
                    }
                
                it("tracks download")
                    {
                    metrics.requestBytesSent = 1000
                    metrics.requestBytesTotal = 1000
                    metrics.responseBytesReceived = 1
                    metrics.responseBytesTotal = 1000
                    expectProgressToIncrease
                        { metrics.responseBytesReceived = 2 }
                    }
                }
            }
        }
    }
