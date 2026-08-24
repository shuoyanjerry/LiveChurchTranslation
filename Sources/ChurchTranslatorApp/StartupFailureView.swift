import SwiftUI

struct StartupFailureView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("Live Church Translation 无法启动")
                .font(.title2.weight(.semibold))
            Text("请重新安装应用后再试。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(minWidth: 720, minHeight: 480)
    }
}
