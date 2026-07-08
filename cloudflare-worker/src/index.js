/**
 * Cloudflare Workers - 트렌드 수집 및 API
 * Python FastAPI 백엔드를 완전 대체
 */

// RSS 피드 목록 (Python scraper.py와 동일)
const RSS_FEEDS = {
  '경제': [
    'https://finance.yahoo.com/news/rssindex',
    'https://finance.yahoo.com/rss/topstories',    
    'http://www.hankyung.com/feed/economy.xml',    
    'https://news.sbs.co.kr/news/SectionRssFeed.do?sectionId=02',    
    'https://www.newsis.com/RSS/economy.xml',    
  ],
  '사회': [        
    'https://www.yonhapnews.co.kr/RSS/society.xml',
    'http://www.hankyung.com/feed/society.xml',
    'https://news.sbs.co.kr/news/SectionRssFeed.do?sectionId=03',
    'https://www.newsis.com/RSS/society.xml',

  ],
  '정치': [    
    'https://www.yonhapnews.co.kr/RSS/politics.xml',
    'http://www.hankyung.com/feed/politics.xml',
    'https://news.sbs.co.kr/news/SectionRssFeed.do?sectionId=01',
    'https://www.newsis.com/RSS/politics.xml',
  ],
  '국제': [    
    'https://www.yonhapnews.co.kr/RSS/international.xml',
    'http://www.hankyung.com/feed/international.xml',  
    'https://news.sbs.co.kr/news/SectionRssFeed.do?sectionId=04',  
    'https://www.newsis.com/RSS/international.xml',  
  ],
  'IT/과학': [    
    'https://feeds.feedburner.com/venturebeat/SZYF', 
    'http://www.hankyung.com/feed/it.xml',   
    'https://news.sbs.co.kr/news/SectionRssFeed.do?sectionId=08',
    'https://www.newsis.com/RSS/health.xml',
  ],
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;

    // CORS 헤더
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      // 라우팅
      if (path === '/' || path === '') {
        return jsonResponse({ message: 'Trend API (Cloudflare Workers)', version: '2.0.0', status: 'healthy' }, corsHeaders);
      }

      if (path === '/api/trends') {
        return await handleGetTrends(url, env, corsHeaders);
      }

      if (path.match(/^\/api\/trends\/\d+$/)) {
        const id = parseInt(path.split('/').pop());
        return await handleGetTrendDetail(id, env, corsHeaders);
      }

      if (path === '/api/scheduler/trigger' && request.method === 'POST') {
        return await handleTriggerCollection(env, corsHeaders);
      }

      // 긴급 디버그: 최신 데이터 확인
      if (path === '/api/debug/latest' && request.method === 'GET') {
        const { data } = await querySupabase(env, 'trends?select=id,korean_title,created_at,category&order=id.desc&limit=5');
        return jsonResponse({ 
          latest_by_id: data,
          supabase_url: env.SUPABASE_URL,
          supabase_key_length: env.SUPABASE_ANON_KEY?.length
        }, corsHeaders);
      }

      return jsonResponse({ error: 'Not found' }, corsHeaders, 404);
    } catch (error) {
      console.error('Error:', error);
      return jsonResponse({ error: error.message }, corsHeaders, 500);
    }
  },

  // 크론 잡 (5분마다 자동 실행)
  async scheduled(event, env, ctx) {
    console.log('=== Cron job started at', new Date().toISOString(), '===');
    
    // 환경변수 체크
    if (!env.GROQ_API_KEY || !env.SUPABASE_URL || !env.SUPABASE_ANON_KEY) {
      console.error('Missing environment variables!');
      console.error('GROQ_API_KEY:', env.GROQ_API_KEY ? 'SET' : 'MISSING');
      console.error('SUPABASE_URL:', env.SUPABASE_URL ? 'SET' : 'MISSING');
      console.error('SUPABASE_ANON_KEY:', env.SUPABASE_ANON_KEY ? 'SET' : 'MISSING');
      return;
    }
    
    try {
      const result = await collectAllNews(env);
      console.log('=== Cron job completed successfully ===');
      console.log('📊 Result:', JSON.stringify(result));
    } catch (error) {
      console.error('=== Cron job failed ===');
      console.error('Error name:', error.name);
      console.error('Error message:', error.message);
      console.error('Error stack:', error.stack);
      throw error; // Cloudflare에 에러 전달
    }
  },
};

// ─────────────────────────────────────────────────
// API 핸들러
// ─────────────────────────────────────────────────

async function handleGetTrends(url, env, corsHeaders) {
  const limit = parseInt(url.searchParams.get('limit') || '20');
  const offset = parseInt(url.searchParams.get('offset') || '0');
  const category = url.searchParams.get('category') || '';
  const sort = (url.searchParams.get('sort') || 'latest').toLowerCase();
  const period = (url.searchParams.get('period') || '').toLowerCase();

  let query = `id,korean_title,summary_kr,importance,tickers,category,link,source,created_at,view_count`;
  let filters = '';
  let order = 'created_at.desc,importance.desc';
  
  if (category) {
    filters = `&category=eq.${encodeURIComponent(category)}`;
  }

  if (period && ['1h', '6h', '24h', '7d'].includes(period)) {
    const hours = period === '1h' ? 1 : period === '6h' ? 6 : period === '7d' ? 168 : 24;
    const cutoff = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();
    filters += `&created_at=gte.${encodeURIComponent(cutoff)}`;
  }

  if (sort === 'featured') {
    order = 'importance.desc,created_at.desc';
  } else if (sort === 'popular') {
    order = 'view_count.desc,importance.desc,created_at.desc';
  } else {
    order = 'created_at.desc,importance.desc';
  }

  const { data, error } = await querySupabase(
    env, 
    `trends?select=${query}${filters}&order=${order}&limit=${limit}&offset=${offset}`
  );

  if (error) throw new Error(error.message || 'Failed to fetch trends');

  return jsonResponse({
    success: true,
    count: data.length,
    offset,
    category,
    sort,
    period,
    has_more: data.length === limit,
    data: data.map(row => ({
      ...row,
      tickers: row.tickers ? row.tickers.split(',') : [],
    })),
  }, corsHeaders);
}

async function handleGetTrendDetail(id, env, corsHeaders) {
  const { data, error } = await querySupabase(env, `trends?id=eq.${id}`, 'GET', null, true);

  if (error || !data) {
    return jsonResponse({ error: 'Trend not found' }, corsHeaders, 404);
  }

  // 조회수 증가
  await querySupabase(env, `trends?id=eq.${id}`, 'PATCH', { view_count: data.view_count + 1 });

  return jsonResponse({ success: true, data }, corsHeaders);
}

async function handleTriggerCollection(env, corsHeaders) {
  console.log('=== Manual trigger requested ===');
  
  try {
    // 동기로 실행하여 결과 반환
    const result = await collectAllNews(env);
    return jsonResponse({ 
      success: true, 
      message: 'Collection completed', 
      result 
    }, corsHeaders);
  } catch (error) {
    console.error('Collection error:', error.message);
    return jsonResponse({ 
      success: false, 
      error: error.message 
    }, corsHeaders, 500);
  }
}

// ─────────────────────────────────────────────────
// 뉴스 수집 및 분석
// ─────────────────────────────────────────────────

async function collectAllNews(env) {
  console.log('=== Starting news collection (Round-Robin) ===');
  
  // 카테고리 순환을 위한 인덱스 저장 (정확한 시간 기반 순환 로직)
  const categories = Object.keys(RSS_FEEDS);
  const now = new Date();
  const currentMinute = now.getMinutes(); 
  // 5분마다 실행되므로 5로 나눈 몫을 사용해야 0, 1, 2, 3, 4로 정상 순환합니다.
  const categoryIndex = Math.floor(currentMinute / 5) % categories.length;
  const currentCategory = categories[categoryIndex];
  
  console.log(`Processing category [${categoryIndex + 1}/${categories.length}]: ${currentCategory}`);
  
  let totalFetched = 0;
  let totalAnalyzed = 0;
  let totalInserted = 0;
  const errors = [];

  try {
    // 1. 현재 카테고리만 RSS 수집
    const feeds = RSS_FEEDS[currentCategory];
    console.log(`📰 [${currentCategory}] Fetching from ${feeds.length} RSS feeds...`);
    // TPM 6000 한도를 넘지 않도록 8개로 조정
    const articles = await fetchRSSFeeds(feeds, 8);
    totalFetched = articles.length;
    console.log(`✅ [${currentCategory}] Fetched ${articles.length} articles`);
    
    if (articles.length === 0) {
      console.log('No articles found');
      return { 
        category: currentCategory,
        totalFetched: 0, 
        totalAnalyzed: 0, 
        totalInserted: 0, 
        timestamp: new Date().toISOString() 
      };
    }

    // 2. AI 분석 (순차 처리)
    console.log(`🤖 Starting AI analysis for ${articles.length} articles...`);
    const analyzed = [];
    
    for (const article of articles) {
      try {
        const result = await analyzeSingleArticle({ ...article, category: currentCategory }, env);
        if (result) {
          analyzed.push(result);
          console.log(`  ✓ Analyzed: ${result.korean_title.slice(0, 40)}`);
        }
        // Groq API Rate Limit 방지: TPM 리필 속도를 고려해 1초 지연
        await new Promise(resolve => setTimeout(resolve, 1000));
      } catch (error) {
        console.error(`  ✗ Analysis failed: "${article.title.slice(0, 30)}" - ${error.message}`);
        errors.push({ article: article.title.slice(0, 30), phase: 'analyze', error: error.message });
      }
    }
    
    totalAnalyzed = analyzed.length;
    console.log(`✅ Analyzed ${totalAnalyzed}/${articles.length} articles successfully`);

    if (analyzed.length === 0) {
      console.log('No analyzed articles');
      return { 
        category: currentCategory,
        totalFetched, 
        totalAnalyzed: 0, 
        totalInserted: 0, 
        timestamp: new Date().toISOString() 
      };
    }

    // 3. 배치 삽입
    console.log(`💾 Inserting ${analyzed.length} analyzed articles to database...`);
    totalInserted = await insertTrends(analyzed, env);
    console.log(`✅ Successfully inserted ${totalInserted} new trends`);

    // 4. 정리 (매 5번째 실행마다만 - 전체 순환 완료 시)
    if (categoryIndex === 0) {
      try {
        console.log('Running cleanup (full cycle completed)...');
        await cleanupOldTrends(env, 7);
      } catch (error) {
        console.error('Cleanup error:', error.message);
      }
    }
    
  } catch (error) {
    console.error(`[${currentCategory}] ERROR:`, error.message);
    errors.push({ category: currentCategory, phase: 'collection', error: error.message });
  }
  
  const result = {
    category: currentCategory,
    categoryIndex: categoryIndex + 1,
    totalCategories: categories.length,
    nextCategory: categories[(categoryIndex + 1) % categories.length],
    totalFetched,
    totalAnalyzed,
    totalInserted,
    errors: errors.length > 0 ? errors : undefined,
    timestamp: new Date().toISOString()
  };
  
  console.log(`=== Completed [${currentCategory}]: ${totalInserted} inserted ===`);
  return result; // 중복되어 있던 괄호와 리턴문을 제거하여 깔끔하게 수정했습니다.
}

// 단일 기사 분석 함수 (분리)
async function analyzeSingleArticle(article, env) {
  const isKorean = /[\uAC00-\uD7A3]/.test(article.title);
  
  const prompt = isKorean
    ? `다음 한국어 뉴스를 분석해주세요:

제목: ${article.title}
내용: ${article.description}

반드시 아래 형식의 JSON으로만 응답하세요. 다른 설명 없이 JSON만 반환하세요:
{
  "korean_title": "원본 제목을 그대로 사용",
  "summary_kr": "2~3줄 핵심 요약",
  "importance": 3,
  "tickers": [],
  "category": "${article.category}"
}

importance는 1~5 정수 (중요도), tickers는 관련 주식 종목코드 배열`
    : `다음 영문 뉴스를 한국어로 분석해주세요:

제목: ${article.title}
내용: ${article.description}

반드시 아래 형식의 JSON으로만 응답하세요. 다른 설명 없이 JSON만 반환하세요:
{
  "korean_title": "한국어로 번역된 제목",
  "summary_kr": "2~3줄 한국어 핵심 요약",
  "importance": 3,
  "tickers": [],
  "category": "${article.category}"
}

importance는 1~5 정수 (중요도), tickers는 관련 주식 종목코드 배열`;

  // Groq API 사용
  const aiResponse = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${env.GROQ_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'llama-3.1-8b-instant',
      messages: [
        { 
          role: 'system', 
          content: 'You are a JSON-only API. Always return valid JSON without any markdown formatting or explanation.' 
        },
        { role: 'user', content: prompt }
      ],
      max_tokens: 512,
      temperature: 0.3, // 더 결정적으로
      response_format: { type: "json_object" }, // JSON 모드 강제
    }),
    signal: AbortSignal.timeout(30000),
  });

  if (!aiResponse.ok) {
    const errorText = await aiResponse.text();
    console.error(`Groq API error: ${aiResponse.status} - ${errorText}`);
    return null;
  }

  const aiData = await aiResponse.json();
  const content = aiData.choices?.[0]?.message?.content || '{}';
  const analysis = parseJSON(content);

  if (!analysis.korean_title || !analysis.summary_kr) {
    console.error(`❌ Invalid analysis result for "${article.title.slice(0, 40)}"`);
    console.error(`AI Response: ${content.slice(0, 200)}`);
    console.error(`Parsed: korean_title=${!!analysis.korean_title}, summary_kr=${!!analysis.summary_kr}`);
    return null;
  }

  return {
    original_title: article.title,
    korean_title: analysis.korean_title || article.title,
    summary_kr: analysis.summary_kr || '',
    importance: parseInt(analysis.importance) || 3,
    tickers: (analysis.tickers || []).join(','),
    category: article.category,
    link: article.link,
    published: article.pubDate,
    source: article.source,
    created_at: article.pubDate || new Date().toISOString(), // RSS 발행 시간 우선 사용
  };
}

async function fetchRSSFeeds(feedUrls, limit) {
  const allArticles = [];

  for (const feedUrl of feedUrls) {
    try {
      console.log(`Fetching RSS: ${feedUrl}`);
      const response = await fetch(feedUrl, { 
        headers: { 
          'User-Agent': 'Mozilla/5.0',
          'Accept-Charset': 'utf-8'
        },
        signal: AbortSignal.timeout(20000),
      });
      
      if (!response.ok) {
        console.error(`RSS fetch failed: ${feedUrl} - ${response.status}`);
        continue;
      }
      
      // ArrayBuffer로 읽어서 UTF-8로 명시적으로 디코딩
      const buffer = await response.arrayBuffer();
      const decoder = new TextDecoder('utf-8');
      const text = decoder.decode(buffer);

      // RSS XML 파싱 (간단한 정규식)
      const items = text.match(/<item>[\s\S]*?<\/item>/gi) || [];
      console.log(`Found ${items.length} items in ${feedUrl}`);
      
      for (const item of items.slice(0, limit)) {
        const title = extractTag(item, 'title');
        const link = extractTag(item, 'link');
        const description = extractTag(item, 'description')?.slice(0, 500) || '';
        const pubDate = extractTag(item, 'pubDate') || '';

        if (title && link) {
          allArticles.push({ 
            title, 
            link, 
            description, 
            pubDate, 
            source: new URL(feedUrl).hostname 
          });
        }

        if (allArticles.length >= limit * feedUrls.length) break;
      }

      if (allArticles.length >= limit * feedUrls.length) break;
    } catch (error) {
      console.error(`Error fetching ${feedUrl}:`, error.message);
      // 에러 발생해도 계속 진행 (다른 피드에서 데이터 가져오기)
      continue;
    }
  }

  // 중복 제거
  const unique = [];
  const seen = new Set();
  for (const article of allArticles) {
    if (!seen.has(article.title)) {
      seen.add(article.title);
      unique.push(article);
    }
  }

  console.log(`Total unique articles: ${unique.length} from ${feedUrls.length} feeds`);
  return unique.slice(0, limit);
}

async function analyzeArticles(articles, category, env) {
  const analyzed = [];

  for (const article of articles) {
    try {
      const isKorean = /[\uAC00-\uD7A3]/.test(article.title);
      
      const prompt = isKorean
        ? `다음 한국어 뉴스를 분석해주세요:

제목: ${article.title}
내용: ${article.description}

반드시 JSON 형식으로만 응답하세요:
{
  "korean_title": "${article.title}",
  "summary_kr": "2~3줄 핵심 요약",
  "importance": 3,
  "tickers": [],
  "category": "${category}"
}

importance는 1~5 정수, tickers는 관련 주식 종목코드 배열`
        : `다음 영문 뉴스를 한국어로 분석해주세요:

제목: ${article.title}
내용: ${article.description}

반드시 JSON 형식으로만 응답하세요:
{
  "korean_title": "한국어 번역 제목",
  "summary_kr": "2~3줄 한국어 핵심 요약",
  "importance": 3,
  "tickers": [],
  "category": "${category}"
}`;

      // Groq API 사용 (무료 - 일 14,400 요청)
      const aiResponse = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.GROQ_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'llama-3.1-8b-instant',
          messages: [{ role: 'user', content: prompt }],
          max_tokens: 512,
          temperature: 0.5,
        }),
        signal: AbortSignal.timeout(30000), // 30초 타임아웃
      });

      if (!aiResponse.ok) {
        const errorText = await aiResponse.text();
        console.error(`Groq API error: ${aiResponse.status} - ${errorText}`);
        continue;
      }

      const aiData = await aiResponse.json();
      const content = aiData.choices?.[0]?.message?.content || '{}';
      const analysis = parseJSON(content);

      if (!analysis.korean_title || !analysis.summary_kr) {
        console.error(`Invalid analysis result for: ${article.title.slice(0, 30)}`);
        continue;
      }

      analyzed.push({
        original_title: article.title,
        korean_title: analysis.korean_title || article.title,
        summary_kr: analysis.summary_kr || '',
        importance: parseInt(analysis.importance) || 3,
        tickers: (analysis.tickers || []).join(','),
        category,
        link: article.link,
        published: article.pubDate,
        source: article.source,
        created_at: new Date().toISOString(),
      });
    } catch (error) {
      console.error(`Error analyzing article "${article.title.slice(0, 30)}":`, error.message);
    }
  }

  return analyzed;
}

async function insertTrends(trends, env) {
  if (trends.length === 0) return 0;
  
  let inserted = 0;
  let skipped = 0;

  try {
    // 1. 최근 24시간 동안 저장된 기사의 링크와 제목 가져오기
    const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    
    console.log("Fetching recent links and titles from Supabase for duplicate check...");
    const { data: existing, error: fetchError } = await querySupabase(
      env,
      `trends?select=link,korean_title&created_at=gte.${twentyFourHoursAgo}`
    );

    if (fetchError) {
      throw new Error(`Failed to fetch existing data: ${JSON.stringify(fetchError)}`);
    }

    // DB에 이미 존재하는 링크와 제목을 Set에 저장
    const existingLinks = new Set((existing || []).map(row => row.link));
    const existingTitles = new Set((existing || []).map(row => row.korean_title?.trim().toLowerCase()));
    console.log(`Loaded ${existingLinks.size} existing links and ${existingTitles.size} titles from the last 24 hours.`);

    // 2. 링크와 제목 모두 확인하여 중복 필터링
    const newTrends = trends.filter(trend => {
      const normalizedTitle = trend.korean_title?.trim().toLowerCase();
      
      // 링크가 중복인 경우
      if (existingLinks.has(trend.link)) {
        console.log(`⏭️ Duplicate (link): ${trend.korean_title.slice(0, 40)}`);
        skipped++;
        return false;
      }
      
      // 제목이 중복인 경우 (같은 기사가 다른 URL로 배포될 수 있음)
      if (normalizedTitle && existingTitles.has(normalizedTitle)) {
        console.log(`⏭️ Duplicate (title): ${trend.korean_title.slice(0, 40)}`);
        skipped++;
        return false;
      }
      
      return true;
    });

    console.log(`📊 Filter result: ${newTrends.length} new / ${skipped} duplicates / ${trends.length} total`);

    if (newTrends.length === 0) {
      console.log('All fetched items are identified as duplicates. No new data to insert.');
      return 0;
    }

    console.log(`Inserting ${newTrends.length} brand new trends into Supabase...`);

    // 3. 일괄 배치 삽입 실행
    const { data: insertData, error: insertError } = await querySupabase(env, 'trends', 'POST', newTrends);

    if (insertError) {
      console.error('❌ Batch insert failed:', JSON.stringify(insertError));
      console.error('Falling back to individual insertion...');
      // 배치 실패 시 안전장치로 개별 삽입 시도
      for (const trend of newTrends) {
        const { error: singleError } = await querySupabase(env, 'trends', 'POST', trend);
        if (!singleError) {
          inserted++;
          console.log(`  ✓ Individual insert: ${trend.korean_title.slice(0, 30)}`);
        } else {
          console.error(`  ✗ Failed: ${trend.korean_title.slice(0, 30)} - ${JSON.stringify(singleError)}`);
        }
      }
    } else {
      inserted = newTrends.length;
      console.log(`✅ Successfully batch-inserted ${inserted} trends`);
      
      // 삽입된 ID 범위 로그
      if (insertData && insertData.length > 0) {
        const ids = insertData.map(d => d.id);
        console.log(`📝 Inserted IDs: ${ids[0]} ~ ${ids[ids.length - 1]}`);
      }
    }

  } catch (error) {
    console.error(`Error in insertTrends execution:`, error.message);
  }

  console.log(`Insert summary: ${inserted} inserted, ${skipped} skipped as duplicates`);
  return inserted;
}

async function cleanupOldTrends(env, days) {
  try {
    const cutoffDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
    
    // 먼저 삭제할 항목 개수 확인
    const { data: countData } = await querySupabase(
      env,
      `trends?select=id&created_at=lt.${cutoffDate}&limit=1`
    );
    
    if (!countData || countData.length === 0) {
      console.log(`No old trends to cleanup (older than ${days} days)`);
      return;
    }
    
    // 삭제 실행 (PostgREST는 자동으로 효율적으로 처리)
    const { error } = await querySupabase(
      env, 
      `trends?created_at=lt.${cutoffDate}`,
      'DELETE'
    );

    if (error) {
      console.error('Cleanup error:', JSON.stringify(error));
    } else {
      console.log(`Cleaned up trends older than ${days} days (before ${cutoffDate})`);
    }
  } catch (error) {
    console.error('Cleanup exception:', error.message);
  }
}

// ─────────────────────────────────────────────────
// Supabase REST API 헬퍼 (간소화)
// ─────────────────────────────────────────────────

async function querySupabase(env, endpoint, method = 'GET', body = null, single = false) {
  const url = `${env.SUPABASE_URL}/rest/v1/${endpoint}`;
  const headers = {
    'apikey': env.SUPABASE_ANON_KEY,
    'Authorization': `Bearer ${env.SUPABASE_ANON_KEY}`,
    'Content-Type': 'application/json',
  };

  if (single) {
    headers['Accept'] = 'application/vnd.pgrst.object+json';
  }

  if (method !== 'GET' && method !== 'DELETE') {
    headers['Prefer'] = 'return=representation';
  }

  const options = {
    method,
    headers,
  };

  if (body) {
    options.body = JSON.stringify(body);
  }

  try {
    const response = await fetch(url, options);
    
    if (!response.ok) {
      const errorText = await response.text();
      console.error(`Supabase error: ${response.status} - ${errorText}`);
      return { data: null, error: { message: errorText, status: response.status } };
    }

    // DELETE는 body 없음
    if (method === 'DELETE') {
      return { data: true, error: null };
    }

    const data = await response.json();
    
    return { data, error: null };
  } catch (error) {
    console.error('Supabase request failed:', error.message);
    return { data: null, error: { message: error.message } };
  }
}

// ─────────────────────────────────────────────────
// 유틸리티
// ─────────────────────────────────────────────────

function jsonResponse(data, headers = {}, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...headers },
  });
}

function extractTag(xml, tagName) {
  const regex = new RegExp(`<${tagName}[^>]*><!\\[CDATA\\[([\\s\\S]*?)\\]\\]><\\/${tagName}>|<${tagName}[^>]*>([\\s\\S]*?)<\\/${tagName}>`, 'i');
  const match = xml.match(regex);
  const rawText = match ? (match[1] || match[2] || '').trim() : '';
  
  // HTML 엔티티 디코딩
  return decodeHTMLEntities(rawText);
}

function decodeHTMLEntities(text) {
  if (!text) return '';
  
  // 자주 사용되는 HTML 엔티티 변환
  const entities = {
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&apos;': "'",
    '&#39;': "'",
    '&nbsp;': ' ',
  };
  
  let decoded = text;
  
  // 기본 엔티티 변환
  for (const [entity, char] of Object.entries(entities)) {
    decoded = decoded.replace(new RegExp(entity, 'g'), char);
  }
  
  // 숫자 엔티티 변환 (&#xxxx; 형태)
  decoded = decoded.replace(/&#(\d+);/g, (match, dec) => {
    return String.fromCharCode(dec);
  });
  
  // 16진수 엔티티 변환 (&#xHHHH; 형태)
  decoded = decoded.replace(/&#x([0-9A-Fa-f]+);/g, (match, hex) => {
    return String.fromCharCode(parseInt(hex, 16));
  });
  
  return decoded;
}

function parseJSON(text) {
  try {
    // 1. 먼저 전체 텍스트를 JSON으로 파싱 시도
    return JSON.parse(text);
  } catch {
    try {
      // 2. JSON 블록만 추출해서 파싱 시도
      const match = text.match(/\{[\s\S]*\}/);
      if (match) {
        return JSON.parse(match[0]);
      }
    } catch {
      try {
        // 3. 더 관대한 파싱: 백틱, 마크다운 제거 후 시도
        const cleaned = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
        const match = cleaned.match(/\{[\s\S]*\}/);
        if (match) {
          return JSON.parse(match[0]);
        }
      } catch (e) {
        console.error('JSON parse failed:', e.message);
        console.error('Raw text:', text.slice(0, 200));
      }
    }
    return {};
  }
}
