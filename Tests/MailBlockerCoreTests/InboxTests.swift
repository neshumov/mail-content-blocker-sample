import XCTest
@testable import MailBlockerCore

final class InboxTests: XCTestCase {
    func testNothingWaitingAtFirst() {
        XCTAssertNil(OpenedRulesInbox(center: NotificationCenter()).take())
    }

    func testAFileWaitsUntilTheWindowTakesItAndIsTakenOnce() {
        let inbox = OpenedRulesInbox(center: NotificationCenter())
        inbox.deliver(.success("||a.example^"))
        XCTAssertEqual(inbox.take(), .success("||a.example^"))
        XCTAssertNil(inbox.take())
    }

    func testTheLatestFileWins() {
        let inbox = OpenedRulesInbox(center: NotificationCenter())
        inbox.deliver(.success("old"))
        inbox.deliver(.success("new"))
        XCTAssertEqual(inbox.take(), .success("new"))
    }

    func testAFailureIsDeliveredToo() {
        let inbox = OpenedRulesInbox(center: NotificationCenter())
        inbox.deliver(.failure(.notUTF8))
        XCTAssertEqual(inbox.take(), .failure(.notUTF8))
    }

    func testDeliveringPostsANotification() {
        let center = NotificationCenter()
        let inbox = OpenedRulesInbox(center: center)
        let posted = expectation(description: "didArrive")
        let token = center.addObserver(forName: OpenedRulesInbox.didArrive, object: inbox, queue: nil) { _ in
            posted.fulfill()
        }
        inbox.deliver(.success("x"))
        wait(for: [posted], timeout: 1)
        center.removeObserver(token)
    }

    func testAWindowThatIsAlreadyListeningCanTakeTheFileFromTheNotification() {
        let center = NotificationCenter()
        let inbox = OpenedRulesInbox(center: center)
        var received: Result<String, RulesFileError>?
        let token = center.addObserver(forName: OpenedRulesInbox.didArrive, object: inbox, queue: nil) { _ in
            received = inbox.take()
        }
        inbox.deliver(.success("||late.example^"))
        XCTAssertEqual(received, .success("||late.example^"))
        center.removeObserver(token)
    }
}
