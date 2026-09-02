-- Seed Categories
INSERT INTO public.categories (name, icon_url) VALUES
('Malay', 'https://cdn-icons-png.flaticon.com/512/706/706164.png'),
('Chinese', 'https://cdn-icons-png.flaticon.com/512/706/706165.png'),
('Indian', 'https://cdn-icons-png.flaticon.com/512/706/706166.png'),
('Hidden Gem', 'https://cdn-icons-png.flaticon.com/512/706/706167.png'),
('Street Food', 'https://cdn-icons-png.flaticon.com/512/706/706168.png');

-- Seed Restaurants
INSERT INTO public.restaurants (
  name, description, address, city, state, latitude, longitude,
  price_range, categories, popularity_score
) VALUES
('Village Park Nasi Lemak', 'Famous Nasi Lemak in Damansara Uptown. Must try their fried chicken!', '5, Jalan SS 21/37, Damansara Utama, 47400 Petaling Jaya, Selangor', 'Petaling Jaya', 'Selangor', 3.1362, 101.6226, '$$', ARRAY['Malay'], 95),
('Sisters Curry Mee', 'Legendary Curry Mee in Penang. Authentic heritage taste.', '85, Jalan Macalister, George Town, 10400 George Town, Pulau Pinang', 'George Town', 'Pulau Pinang', 5.4164, 100.3226, '$', ARRAY['Chinese'], 82),
('Restoran Kin Kin', 'Original Chili Pan Mee. Spicy and delicious.', '40, Jalan Dewan Sultan Sulaiman, Kampung Baru, 50300 Kuala Lumpur', 'Kuala Lumpur', 'Kuala Lumpur', 3.1611, 101.6978, '$$', ARRAY['Chinese'], 78),
('Ali, Muthu & Ah Hock', 'Kopitiam style food. Great Nasi Lemak and Coffee.', '13, Jalan Balai Polis, City Centre, 50000 Kuala Lumpur', 'Kuala Lumpur', 'Kuala Lumpur', 3.1425, 101.6967, '$$', ARRAY['Malay', 'Chinese', 'Indian'], 74),
('Burp & Giggles', 'Quirky cafe in Ipoh with great burgers and vibes.', '93, Jalan Dhoby, 30000 Ipoh, Perak', 'Ipoh', 'Perak', 4.5956, 101.0782, '$$$', ARRAY['Western'], 70);

-- Seed Achievements
INSERT INTO public.achievements (name, description, icon_url, points) VALUES
('Food Explorer', 'Visit 5 different restaurants.', 'explore_icon', 100),
('Hidden Gem Hunter', 'Find and review 3 hidden gems.', 'gem_icon', 200),
('Top Reviewer', 'Write 10 detailed reviews.', 'review_icon', 300),
('Local Guide', 'Contribute 5 photos to the community.', 'guide_icon', 150);
