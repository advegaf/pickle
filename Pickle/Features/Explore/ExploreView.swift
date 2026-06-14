import SwiftUI

/// Explore: curated collections and categories that open as pre-filtered searches, plus
/// bundled nutrition guides. Photography leads here (unlike the data-forward Home).
struct ExploreView: View {
    @EnvironmentObject private var store: PickleStore
    @State private var searchQuery: String?
    @State private var article: Article?

    private let columns = [GridItem(.flexible(), spacing: Spacing.m),
                           GridItem(.flexible(), spacing: Spacing.m)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                Text("Explore")
                    .font(PickleFont.display(34))
                    .foregroundStyle(Palette.primary)
                    .padding(.top, Spacing.s)

                collections
                categories
                featured
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, 120)
        }
        .background(Palette.background)
        .sheet(item: Binding(get: { searchQuery.map { QueryRef(q: $0) } },
                             set: { searchQuery = $0?.q })) { ref in
            LogSheet(prefillQuery: ref.q).environmentObject(store)
        }
        .sheet(item: $article) { a in
            ArticleReaderView(article: a)
        }
    }

    private var collections: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Eyebrow(text: "Collections")
            LazyVGrid(columns: columns, spacing: Spacing.m) {
                ForEach(Array(FoodCollection.all.enumerated()), id: \.element.id) { i, c in
                    PhotoCard(title: c.title, subtitle: c.subtitle, eyebrow: "Collection",
                              seed: i + 1, height: 150) {
                        searchQuery = c.query; Haptics.select()
                    }
                }
            }
        }
    }

    private var categories: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Eyebrow(text: "Browse by category")
            LazyVGrid(columns: columns, spacing: Spacing.m) {
                ForEach(FoodCategory.allCases) { cat in
                    CategoryButton(title: cat.rawValue) {
                        searchQuery = cat.query; Haptics.select()
                    }
                }
            }
        }
    }

    private var featured: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Eyebrow(text: "Featured reading")
            VStack(spacing: Spacing.m) {
                ForEach(Array(Article.all.enumerated()), id: \.element.id) { i, a in
                    ArticleCard(article: a, seed: i + 20) { article = a }
                }
            }
        }
    }
}

private struct QueryRef: Identifiable { let q: String; var id: String { q } }

/// Editorial article card with the ARTICLE eyebrow and read time.
struct ArticleCard: View {
    let article: Article
    var seed: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                DuotonePlaceholder(seed: seed)
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: "Article", color: Palette.secondary)
                    Text(article.title)
                        .font(PickleFont.heading(19))
                        .foregroundStyle(Palette.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(article.readMins) min read")
                        .font(PickleFont.caption(12))
                        .foregroundStyle(Palette.tertiary)
                }
                .padding(Spacing.m)
            }
            .frame(height: 160)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
            .imageOutline()
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Article: \(article.title), \(article.readMins) minute read")
    }
}

/// Long-form reader in editorial typography.
struct ArticleReaderView: View {
    @Environment(\.dismiss) private var dismiss
    let article: Article

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Eyebrow(text: article.eyebrow)
                        Text(article.title)
                            .font(PickleFont.display(30))
                            .foregroundStyle(Palette.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(article.readMins) min read")
                            .font(PickleFont.caption())
                            .foregroundStyle(Palette.tertiary)
                    }
                    .padding(.top, Spacing.s)

                    ForEach(Array(article.body.enumerated()), id: \.offset) { _, para in
                        Text(para)
                            .font(PickleFont.body(17))
                            .foregroundStyle(Palette.secondary)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Palette.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundStyle(Palette.secondary)
                    }
                }
            }
        }
        .presentationBackground(Palette.background)
    }
}
