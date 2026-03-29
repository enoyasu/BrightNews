//
//  BrightNewsAppTests.swift
//  BrightNewsAppTests
//
//  Created by 榎本康寿 on 2026/03/27.
//

import Testing
@testable import BrightNewsApp

struct BrightNewsAppTests {

    @Test func healingFilterRejectsEndOfLifeCareArticle() async throws {
        let allowed = NewsService.passesFinalFilter(
            title: "終末期の介護知識 低スコアの日本",
            summary: "終末期医療と介護負担に関する調査結果。",
            content: "終末期の介護や満足度の低さを扱う内容。",
            for: .healing
        )

        #expect(allowed == false)
    }

    @Test func goodStoryFilterRejectsEndOfLifeCareArticle() async throws {
        let allowed = NewsService.passesFinalFilter(
            title: "終末期の介護知識 低スコアの日本",
            summary: "終末期医療と介護負担に関する調査結果。",
            content: "介護負担や評価の低さを扱う内容。",
            for: .goodStory
        )

        #expect(allowed == false)
    }

    @Test func goodStoryFilterAllowsVolunteerSupportArticle() async throws {
        let allowed = NewsService.passesFinalFilter(
            title: "被災地で炊き出しボランティア、温かい食事届ける",
            summary: "市民が支援活動に集まり、温かい食事を届けた。",
            content: "災害報道そのものではなく、支援活動が主題の記事。",
            for: .goodStory
        )

        #expect(allowed == true)
    }

}
