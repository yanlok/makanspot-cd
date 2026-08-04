-- Approved demo restaurants used by the review editor.
-- The guards make this safe to run more than once.
INSERT INTO public.restaurants (
  name,
  description,
  address,
  latitude,
  longitude,
  price_range,
  rating,
  review_count,
  is_hidden_gem,
  is_trending,
  is_approved
)
SELECT
  seed.name,
  seed.description,
  seed.address,
  seed.latitude,
  seed.longitude,
  seed.price_range,
  seed.rating,
  seed.review_count,
  seed.is_hidden_gem,
  seed.is_trending,
  true
FROM (
  VALUES
    (
      'Village Park Nasi Lemak',
      'A local favourite known for fragrant nasi lemak and crispy fried chicken.',
      '5, Jalan SS 21/37, Damansara Utama, Petaling Jaya',
      3.1362::double precision,
      101.6226::double precision,
      '$$',
      4.8::decimal,
      2500,
      false,
      true
    ),
    (
      'Soong Kee Beef Noodles',
      'Springy noodles served with savoury minced beef and a comforting broth.',
      '86, Jalan Tun H S Lee, Kuala Lumpur',
      3.1457::double precision,
      101.6967::double precision,
      '$',
      4.5::decimal,
      980,
      true,
      true
    ),
    (
      'Nasi Lemak Wanjo',
      'Classic Kampung Baru nasi lemak with spicy sambal and ayam goreng.',
      '8, Jalan Raja Muda Musa, Kampung Baru, Kuala Lumpur',
      3.1647::double precision,
      101.7067::double precision,
      '$',
      4.4::decimal,
      1400,
      false,
      true
    ),
    (
      'Restoran Kin Kin',
      'The original chilli pan mee with a punchy dry chilli topping.',
      '40, Jalan Dewan Sultan Sulaiman, Kuala Lumpur',
      3.1611::double precision,
      101.6978::double precision,
      '$$',
      4.3::decimal,
      1200,
      false,
      false
    ),
    (
      'Brickfields Pisang Goreng',
      'Freshly fried banana fritters with a crisp, caramelised coating.',
      'Jalan Thambipillay, Brickfields, Kuala Lumpur',
      3.1328::double precision,
      101.6874::double precision,
      '$',
      4.6::decimal,
      620,
      true,
      false
    )
) AS seed (
  name,
  description,
  address,
  latitude,
  longitude,
  price_range,
  rating,
  review_count,
  is_hidden_gem,
  is_trending
)
WHERE NOT EXISTS (
  SELECT 1
  FROM public.restaurants existing
  WHERE lower(existing.name) = lower(seed.name)
);

-- Ensure an existing restaurant with the same name is usable in the picker.
UPDATE public.restaurants
SET is_approved = true
WHERE name IN (
  'Village Park Nasi Lemak',
  'Soong Kee Beef Noodles',
  'Nasi Lemak Wanjo',
  'Restoran Kin Kin',
  'Brickfields Pisang Goreng'
);
