#!/usr/bin/env node

/**
 * Test Pattern Detection Logic
 * Tests concept clustering and sentiment pattern analysis
 */

const Database = require('better-sqlite3');

console.log('🔍 Testing Pattern Detection Logic\n');

try {
  const db = new Database('/Users/chaseeasterling/selene-n8n/data/selene.db', { readonly: true });

  // ==================== TEST 1: Concept Clustering ====================
  console.log('━━━ TEST 1: Concept Clustering ━━━\n');

  const conceptQuery = `
    SELECT
      id,
      raw_note_id,
      concepts,
      primary_theme,
      processed_at
    FROM processed_notes
    WHERE concepts IS NOT NULL
    ORDER BY processed_at DESC
  `;

  const conceptResults = db.prepare(conceptQuery).all();
  console.log(`✓ Found ${conceptResults.length} notes with concepts\n`);

  // Parse and flatten concepts
  const conceptData = [];
  const notesByNote = {};

  conceptResults.forEach(row => {
    try {
      const concepts = JSON.parse(row.concepts);
      const normalizedConcepts = concepts.map(c => c.toLowerCase().trim());

      conceptData.push({
        noteId: row.id,
        concepts: normalizedConcepts,
        theme: row.primary_theme
      });

      normalizedConcepts.forEach(concept => {
        if (!notesByNote[row.id]) {
          notesByNote[row.id] = [];
        }
        notesByNote[row.id].push(concept);
      });
    } catch (e) {
      console.error('Error parsing concepts for note', row.id);
    }
  });

  console.log(`✓ Parsed ${conceptData.length} notes\n`);

  // Find co-occurring concepts
  const coOccurrence = {};

  Object.values(notesByNote).forEach(noteConcepts => {
    if (noteConcepts.length < 2) return;

    for (let i = 0; i < noteConcepts.length; i++) {
      for (let j = i + 1; j < noteConcepts.length; j++) {
        const pair = [noteConcepts[i], noteConcepts[j]].sort().join('|');
        if (!coOccurrence[pair]) {
          coOccurrence[pair] = 0;
        }
        coOccurrence[pair]++;
      }
    }
  });

  const conceptClusters = Object.entries(coOccurrence)
    .filter(([_, count]) => count >= 2)
    .sort((a, b) => b[1] - a[1]);

  console.log(`✓ Found ${conceptClusters.length} concept clusters (2+ co-occurrences)\n`);

  if (conceptClusters.length > 0) {
    console.log('Top 5 Concept Clusters:');
    conceptClusters.slice(0, 5).forEach(([pair, count]) => {
      const [c1, c2] = pair.split('|');
      console.log(`  • "${c1}" + "${c2}" → ${count} times`);
    });
  } else {
    console.log('ℹ️ No concept clusters detected (need at least 2 co-occurrences)');
  }

  console.log('\n');

  // Count concept frequencies for dominant concepts
  const conceptFreq = {};
  conceptData.forEach(item => {
    item.concepts.forEach(concept => {
      if (!conceptFreq[concept]) {
        conceptFreq[concept] = 0;
      }
      conceptFreq[concept]++;
    });
  });

  const dominantConcepts = Object.entries(conceptFreq)
    .filter(([_, count]) => count >= 3)
    .sort((a, b) => b[1] - a[1]);

  console.log(`✓ Found ${dominantConcepts.length} dominant concepts (3+ mentions)\n`);

  if (dominantConcepts.length > 0) {
    console.log('Top 5 Dominant Concepts:');
    dominantConcepts.slice(0, 5).forEach(([concept, count]) => {
      console.log(`  • "${concept}" → ${count} mentions`);
    });
  } else {
    console.log('ℹ️ No dominant concepts detected (need at least 3 mentions)');
  }

  console.log('\n');

  // ==================== TEST 2: Sentiment Patterns ====================
  console.log('━━━ TEST 2: Sentiment Patterns ━━━\n');

  const sentimentQuery = `
    SELECT
      id,
      overall_sentiment,
      sentiment_score,
      energy_level,
      emotional_tone
    FROM processed_notes
    WHERE sentiment_analyzed = 1
    ORDER BY sentiment_analyzed_at DESC
  `;

  const sentimentResults = db.prepare(sentimentQuery).all();
  console.log(`✓ Found ${sentimentResults.length} notes with sentiment analysis\n`);

  // Analyze energy levels
  const energyLevels = {};
  sentimentResults.forEach(row => {
    const level = row.energy_level;
    if (!energyLevels[level]) {
      energyLevels[level] = 0;
    }
    energyLevels[level]++;
  });

  const totalNotes = sentimentResults.length;
  const energyPatterns = Object.entries(energyLevels)
    .map(([level, count]) => ({
      level,
      count,
      percentage: (count / totalNotes * 100).toFixed(1)
    }))
    .filter(e => parseFloat(e.percentage) >= 30);

  console.log('Energy Level Distribution:');
  Object.entries(energyLevels).forEach(([level, count]) => {
    const percentage = (count / totalNotes * 100).toFixed(1);
    console.log(`  • ${level}: ${count} notes (${percentage}%)`);
  });
  console.log('');

  if (energyPatterns.length > 0) {
    console.log('✓ Detected dominant energy patterns (30%+ threshold):');
    energyPatterns.forEach(pattern => {
      console.log(`  • ${pattern.level}: ${pattern.percentage}%`);
    });
  } else {
    console.log('ℹ️ No dominant energy patterns (none exceed 30% threshold)');
  }

  console.log('\n');

  // Analyze sentiments
  const sentiments = {};
  sentimentResults.forEach(row => {
    const sentiment = row.overall_sentiment;
    if (!sentiments[sentiment]) {
      sentiments[sentiment] = {
        count: 0,
        scores: []
      };
    }
    sentiments[sentiment].count++;
    if (row.sentiment_score !== null) {
      sentiments[sentiment].scores.push(row.sentiment_score);
    }
  });

  console.log('Sentiment Distribution:');
  Object.entries(sentiments).forEach(([sentiment, info]) => {
    const percentage = (info.count / totalNotes * 100).toFixed(1);
    const avgScore = info.scores.length > 0
      ? (info.scores.reduce((a, b) => a + b, 0) / info.scores.length).toFixed(2)
      : 'N/A';
    console.log(`  • ${sentiment}: ${info.count} notes (${percentage}%) - avg score: ${avgScore}`);
  });
  console.log('');

  const sentimentPatterns = Object.entries(sentiments)
    .map(([sentiment, info]) => ({
      sentiment,
      count: info.count,
      percentage: (info.count / totalNotes * 100).toFixed(1)
    }))
    .filter(s => parseFloat(s.percentage) >= 25);

  if (sentimentPatterns.length > 0) {
    console.log('✓ Detected significant sentiment patterns (25%+ threshold):');
    sentimentPatterns.forEach(pattern => {
      console.log(`  • ${pattern.sentiment}: ${pattern.percentage}%`);
    });
  } else {
    console.log('ℹ️ No dominant sentiment patterns (none exceed 25% threshold)');
  }

  console.log('\n');

  // Analyze emotional tones
  const tones = {};
  sentimentResults.forEach(row => {
    const tone = row.emotional_tone;
    if (tone && tone !== 'null') {
      if (!tones[tone]) {
        tones[tone] = 0;
      }
      tones[tone]++;
    }
  });

  console.log('Emotional Tone Distribution:');
  Object.entries(tones)
    .sort((a, b) => b[1] - a[1])
    .forEach(([tone, count]) => {
      const percentage = (count / totalNotes * 100).toFixed(1);
      console.log(`  • ${tone}: ${count} notes (${percentage}%)`);
    });
  console.log('');

  const topTone = Object.entries(tones)
    .sort((a, b) => b[1] - a[1])[0];

  if (topTone) {
    const [tone, count] = topTone;
    const percentage = (count / totalNotes * 100).toFixed(1);

    if (parseFloat(percentage) >= 20) {
      console.log(`✓ Detected dominant emotional tone: ${tone} (${percentage}%)\n`);
    } else {
      console.log(`ℹ️ No dominant emotional tone (highest is ${tone} at ${percentage}%)\n`);
    }
  }

  // ==================== SUMMARY ====================
  console.log('━━━ SUMMARY ━━━\n');

  const patternsDetected =
    conceptClusters.length +
    dominantConcepts.length +
    energyPatterns.length +
    sentimentPatterns.length +
    (topTone && parseFloat((topTone[1] / totalNotes * 100).toFixed(1)) >= 20 ? 1 : 0);

  console.log(`Total Patterns Detected: ${patternsDetected}`);
  console.log(`  • Concept Clusters: ${conceptClusters.length}`);
  console.log(`  • Dominant Concepts: ${dominantConcepts.length}`);
  console.log(`  • Energy Patterns: ${energyPatterns.length}`);
  console.log(`  • Sentiment Patterns: ${sentimentPatterns.length}`);
  console.log(`  • Emotional Tone Patterns: ${topTone && parseFloat((topTone[1] / totalNotes * 100).toFixed(1)) >= 20 ? 1 : 0}`);

  console.log('\n✅ Pattern detection test complete!\n');

  db.close();

} catch (error) {
  console.error('❌ Error:', error.message);
  process.exit(1);
}
