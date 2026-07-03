import WidgetKit
import SwiftUI

@main
struct PickleWidgetBundle: WidgetBundle {
    var body: some Widget {
        PickleWidget()
        PickleMacrosWidget()
    }
}
