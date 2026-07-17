-- Seed Categories
INSERT INTO public.categories (name, icon_url) VALUES
('Malay', 'https://cdn-icons-png.flaticon.com/512/706/706164.png'),
('Chinese', 'https://cdn-icons-png.flaticon.com/512/706/706165.png'),
('Indian', 'https://cdn-icons-png.flaticon.com/512/706/706166.png'),
('Hidden Gem', 'https://cdn-icons-png.flaticon.com/512/706/706167.png'),
('Street Food', 'https://cdn-icons-png.flaticon.com/512/706/706168.png');

-- Seed Restaurants
INSERT INTO public.restaurants (name, description, address, latitude, longitude, price_range, rating, review_count, is_hidden_gem, is_trending, is_approved) VALUES
('Village Park Nasi Lemak', 'Famous Nasi Lemak in Damansara Uptown. Must try their fried chicken!', '5, Jalan SS 21/37, Damansara Utama, 47400 Petaling Jaya, Selangor', 3.1362, 101.6226, '$$', 4.8, 2500, false, true, true),
('Sisters Curry Mee', 'Legendary Curry Mee in Penang. Authentic heritage taste.', '85, Jalan Macalister, George Town, 10400 George Town, Pulau Pinang', 5.4164, 100.3226, '$', 4.5, 800, true, false, true),
('Restoran Kin Kin', 'Original Chili Pan Mee. Spicy and delicious.', '40, Jalan Dewan Sultan Sulaiman, Kampung Baru, 50300 Kuala Lumpur', 3.1611, 101.6978, '$$', 4.3, 1200, false, true, true),
('Ali, Muthu & Ah Hock', 'Kopitiam style food. Great Nasi Lemak and Coffee.', '13, Jalan Balai Polis, City Centre, 50000 Kuala Lumpur', 3.1425, 101.6967, '$$', 4.2, 1500, false, true, true),
('Burp & Giggles', 'Quirky cafe in Ipoh with great burgers and vibes.', '93, Jalan Dhoby, 30000 Ipoh, Perak', 4.5956, 101.0782, '$$$', 4.4, 600, true, true, true);

-- Seed Restaurant Categories
INSERT INTO public.restaurant_categories (restaurant_id, category_id) VALUES
(1, 1), (1, 5),
(2, 2), (2, 4), (2, 5),
(3, 2), (3, 5),
(4, 1), (4, 2), (4, 3),
(5, 4);

-- Seed Achievements
INSERT INTO public.achievements (name, description, icon_url, points) VALUES
('Food Explorer', 'Visit 5 different restaurants.', 'explore_icon', 100),
('Hidden Gem Hunter', 'Find and review 3 hidden gems.', 'gem_icon', 200),
('Top Reviewer', 'Write 10 detailed reviews.', 'review_icon', 300),
('Local Guide', 'Contribute 5 photos to the community.', 'guide_icon', 150);
