# Human scoring sheet

Mark every question **valid** or **invalid**, then record your
verdicts in `eval/results/human_scores.csv` with the header:

```
note_id,index,verdict
01_number_operations_p6_math,1,valid
01_number_operations_p6_math,2,invalid
```

Re-run the harness afterwards; your verdicts override the
automatic ones and the report is relabelled FINAL.

A question is **valid** when all of these hold:
1. The marked answer is genuinely correct according to the note.
2. The question is about something worth teaching (not trivia or a fragment).
3. A blind student could answer it from listening alone.
4. The three distractors are clearly wrong but plausible.

---

## Higher Number Operations (Mathematics, P.6)

**1. What is the place value?**

- A. divisible by 10 if its last digit is 0
- B. the position of a digit in a number ←
- C. a pattern of adding 2 each time
- D. divisible by 2 if its last digit is even

- Auto: PASS
- Concepts hit: place_value
- Explanation: From your lesson: The place value is the position of a digit in a number (like Ones, Tens, Hundreds, Thousands, Ten Thousands, Hundred Thousands, Millions).
- **Verdict (`01_number_operations_p6_math,1`): ______**

**2. Fill in the blank. In the number 4,567,890, the digit 5 is in the blank place, so its total value is 500,000.**

- A. Primary Six
- B. Ten Thousands
- C. billions
- D. Hundred Thousands ←

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: In the number 4,567,890, the digit 5 is in the Hundred Thousands place, so its total value is 500,000.
- **Verdict (`01_number_operations_p6_math,2`): ______**

**3. What are addends?**

- A. the sum
- B. the numbers being added ←
- C. done from left to right
- D. in the Hundred Thousands place

- Auto: PASS
- Concepts hit: addends
- Explanation: From your lesson: Addends are the numbers being added.
- **Verdict (`01_number_operations_p6_math,3`): ______**

**4. When is a number divisible by 2?**

- A. it is divisible by both 2 and 3
- B. its last digit is even ←
- C. its last digit is 0
- D. its last digit is 0 or 5

- Auto: PASS
- Concepts hit: divisibility_two
- Explanation: From your lesson: A number is divisible by 2 if its last digit is even (0, 2, 4, 6, 8).
- **Verdict (`01_number_operations_p6_math,4`): ______**

---

## Living and Non-Living Things (Science, P.3)

**1. Fill in the blank. Even a seed (like a bean seed) is a blank thing.**

- A. chalkboard
- B. matoke
- C. animals
- D. Living ←

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: Even a seed (like a bean seed) is a living thing.
- **Verdict (`02_living_things_p3_science,1`): ______**

---

## Food and Nutrition (Science, P.4)

**1. What is water?**

- A. so important that we learn more
- B. not just tasty – they have three times more protein than beef!
- C. the only nutrient you cannot live without for more than a few ←
- D. a meal that contains all six classes of food in the right

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: Water is the only nutrient you cannot live without for more than a few days.
- **Verdict (`03_food_nutrition_p4_science,1`): ______**

**2. What is a balanced diet?**

- A. the only nutrient you cannot live without for more than a few
- B. so important that we learn more
- C. a meal that contains all six classes of food in the right ←
- D. not just tasty – they have three times more protein than beef!

- Auto: PASS
- Concepts hit: balanced_diet
- Explanation: From your lesson: A balanced diet is a meal that contains all six classes of food in the right amounts.
- **Verdict (`03_food_nutrition_p4_science,2`): ______**

**3. What is mukene (silver fish)?**

- A. a school-going child
- B. very good for children ←
- C. anything we eat or drink
- D. so important that we learn more

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: Mukene (silver fish) is very good for children because you eat the whole fish – bones and all – which gives calcium for strong teeth and bones!
- **Verdict (`03_food_nutrition_p4_science,3`): ______**

**4. What are nsenene (grasshoppers)?**

- A. the only nutrient you cannot live without for more than a few
- B. a meal that contains all six classes of food in the right
- C. not just tasty – they have three times more protein than beef! ←
- D. so important that we learn more

- Auto: PASS
- Concepts hit: proteins
- Explanation: From your lesson: Nsenene (grasshoppers) are not just tasty – they have three times more protein than beef!
- **Verdict (`03_food_nutrition_p4_science,4`): ______**

**5. Fill in the blank. A ripe mango has more blank C than an orange.**

- A. Sewerage
- B. Vitamin ←
- C. oxygen
- D. Carbohydrates

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: A ripe mango has more Vitamin C than an orange.
- **Verdict (`03_food_nutrition_p4_science,5`): ______**

---

## Water (Science, P.5)

**1. What is water?**

- A. the commonest method of making water safe at home
- B. a disease that causes diarrhoea with blood in the stool
- C. diseases that people get from drinking unsafe water
- D. used at home and at school for many activities ←

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: Water is used at home and at school for many activities.
- **Verdict (`04_water_p5_science,1`): ______**

**2. What is melting?**

- A. the ordinary water we drink from a cup
- B. the change from liquid water to ice
- C. the change from ice to liquid water ←
- D. diseases that people get from drinking unsafe water

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: Melting is the change from ice to liquid water.
- **Verdict (`04_water_p5_science,2`): ______**

**3. What is freezing?**

- A. the change from ice to liquid water
- B. the change from liquid water to ice ←
- C. the ordinary water we drink from a cup
- D. diseases that people get from drinking unsafe water

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: Freezing is the change from liquid water to ice.
- **Verdict (`04_water_p5_science,3`): ______**

**4. What is boiling?**

- A. the commonest method of making water safe at home ←
- B. a disease that causes diarrhoea with blood in the stool
- C. the ordinary water we drink from a cup
- D. used at home and at school for many activities

- Auto: PASS
- Concepts hit: boiling
- Explanation: From your lesson: Boiling is the commonest method of making water safe at home.
- **Verdict (`04_water_p5_science,4`): ______**

**5. What is sedimentation?**

- A. a disease that causes diarrhoea with blood in the stool
- B. the process of letting dirt settle at the bottom of a container ←
- C. also used in industries for making drinks and for cooling machines
- D. used at home and at school for many activities

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: Sedimentation is the process of letting dirt settle at the bottom of a container.
- **Verdict (`04_water_p5_science,5`): ______**

**6. What are water borne diseases?**

- A. diseases that people get from drinking unsafe water ←
- B. the change from liquid water to ice
- C. the change from ice to liquid water
- D. the ordinary water we drink from a cup

- Auto: PASS
- Concepts hit: safe_water
- Explanation: From your lesson: Water borne diseases are diseases that people get from drinking unsafe water.
- **Verdict (`04_water_p5_science,6`): ______**

**7. What is cholera?**

- A. used at home and at school for many activities
- B. the commonest method of making water safe at home
- C. a water borne disease that causes severe diarrhoea and vomiting ←
- D. a disease that causes diarrhoea with blood in the stool

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: Cholera is a water borne disease that causes severe diarrhoea and vomiting.
- **Verdict (`04_water_p5_science,7`): ______**

**8. What is typhoid?**

- A. the process of letting dirt settle at the bottom of a container
- B. a disease that causes diarrhoea with blood in the stool
- C. also used in industries for making drinks and for cooling machines
- D. a water borne disease that causes high fever and stomach pain ←

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: Typhoid is a water borne disease that causes high fever and stomach pain.
- **Verdict (`04_water_p5_science,8`): ______**

---

## The Digestive System (Science, P.6)

**1. What is digestion?**

- A. a condition where a person fails to pass out faeces easily
- B. the destruction of a tooth caused by germs acting on sugar
- C. the process by which food is broken down into small particles ←
- D. the long tube that runs from the mouth to the anus

- Auto: PASS
- Concepts hit: digestion_definition
- Explanation: From your lesson: Digestion is the process by which food is broken down into small particles
- **Verdict (`05_digestive_system_p6_science,1`): ______**

**2. What is the digestive system?**

- A. the part that stores faeces before they are passed out
- B. the large back teeth used for chewing and grinding food
- C. prevented by eating foods with roughage and drinking enough water
- D. the group of organs that work together to digest food ←

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: The digestive system is the group of organs that work together to digest food.
- **Verdict (`05_digestive_system_p6_science,2`): ______**

**3. What is the alimentary canal?**

- A. the tube that carries food from the mouth to the stomach
- B. the process by which food is broken down into small particles
- C. the long tube that runs from the mouth to the anus ←
- D. a condition where a person fails to pass out faeces easily

- Auto: PASS
- Concepts hit: alimentary_canal
- Explanation: From your lesson: The alimentary canal is the long tube that runs from the mouth to the anus.
- **Verdict (`05_digestive_system_p6_science,3`): ______**

**4. What is the mouth?**

- A. the acid in the stomach
- B. the liquid in the stomach
- C. the part where digestion begins ←
- D. the wave-like movement of muscles

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: The mouth is the part where digestion begins.
- **Verdict (`05_digestive_system_p6_science,4`): ______**

**5. What are incisors?**

- A. the part where most digestion and absorption take place
- B. the front teeth used for cutting and biting food ←
- C. the largest gland in the body and it produces bile
- D. the large back teeth used for chewing and grinding food

- Auto: PASS
- Concepts hit: incisors
- Explanation: From your lesson: Incisors are the front teeth used for cutting and biting food.
- **Verdict (`05_digestive_system_p6_science,5`): ______**

**6. What is tooth decay?**

- A. the destruction of a tooth caused by germs acting on sugar ←
- B. a condition where a person fails to pass out faeces easily
- C. the tube that carries food from the mouth to the stomach
- D. the process by which food is broken down into small particles

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: Tooth decay is the destruction of a tooth caused by germs acting on sugar.
- **Verdict (`05_digestive_system_p6_science,6`): ______**

**7. What is constipation?**

- A. a condition where a person fails to pass out faeces easily ←
- B. the long tube that runs from the mouth to the anus
- C. the process by which food is broken down into small particles
- D. the tube that carries food from the mouth to the stomach

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: Constipation is a condition where a person fails to pass out faeces easily.
- **Verdict (`05_digestive_system_p6_science,7`): ______**

---

## Weather and Climate (Social Studies, P.5)

**1. What is weather?**

- A. the things that make up the weather of a place
- B. the average weather condition of a place recorded over a long time
- C. the condition of the atmosphere of a place at a particular time ←
- D. the prediction of the weather of a place in advance

- Auto: PASS
- Concepts hit: weather_definition
- Explanation: From your lesson: Weather is the condition of the atmosphere of a place at a particular time.
- **Verdict (`06_weather_climate_p5_sst,1`): ______**

**2. What is climate?**

- A. the instrument used for measuring the speed of the wind
- B. the things that make up the weather of a place
- C. the condition of the atmosphere of a place at a particular time
- D. the average weather condition of a place recorded over a long time ←

- Auto: PASS
- Concepts hit: climate_definition
- Explanation: From your lesson: Climate is the average weather condition of a place recorded over a long time.
- **Verdict (`06_weather_climate_p5_sst,2`): ______**

**3. What is temperature?**

- A. that weather changes from day to day while climate
- B. the degree of hotness or coldness of a place ←
- C. air that is moving from one place to another
- D. the instrument used for measuring the amount of rainfall

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: Temperature is the degree of hotness or coldness of a place.
- **Verdict (`06_weather_climate_p5_sst,3`): ______**

**4. What is a rain gauge?**

- A. the instrument used for measuring the amount of rainfall ←
- B. the instrument that shows the direction of the wind
- C. air that is moving from one place to another
- D. a place where the elements of weather are recorded

- Auto: PASS
- Concepts hit: rain_gauge
- Explanation: From your lesson: A rain gauge is the instrument used for measuring the amount of rainfall.
- **Verdict (`06_weather_climate_p5_sst,4`): ______**

**5. What is altitude?**

- A. the height of a place above sea level ←
- B. the degree of hotness or coldness of a place
- C. the distance of a place from the equator
- D. the instrument used for measuring atmospheric pressure

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: Altitude is the height of a place above sea level.
- **Verdict (`06_weather_climate_p5_sst,5`): ______**

**6. What is weather forecasting?**

- A. the prediction of the weather of a place in advance ←
- B. the instrument used for measuring the speed of the wind
- C. the things that make up the weather of a place
- D. the instrument used for measuring humidity in the air

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: Weather forecasting is the prediction of the weather of a place in advance.
- **Verdict (`06_weather_climate_p5_sst,6`): ______**

**7. Explain why Kabale is colder than Kampala?**

- A. Because Kabale is closer to sea level than Kampala
- B. Because Kabale receives more sunshine than Kampala
- C. Because Kabale is at a higher altitude than Kampala ←
- D. Because Kampala is located on a mountain

- Auto: FAIL (A3_content_bound)
- Concepts hit: none
- Explanation: From your lesson: Places at a high altitude such as Kabale are colder than places at a low altitude.
- **Verdict (`06_weather_climate_p5_sst,7`): ______**

---

## Physical Features of Uganda (Social Studies, P.5)

**1. What are physical features?**

- A. the highest mountain in Uganda and it is found in the west
- B. an extinct volcano that is found in the east of Uganda
- C. the natural things that are found on the surface of the earth ←
- D. small round lakes that form in the mouth of an old volcano

- Auto: PASS
- Concepts hit: features_definition
- Explanation: From your lesson: Physical features are the natural things that are found on the surface of the earth.
- **Verdict (`07_physical_features_p5_sst,1`): ______**

**2. Which is the highest mountain in Uganda and it is found in the west?**

- A. Volcanic mountains
- B. Mount Elgon
- C. mount Rwenzori ←
- D. Crater lakes

- Auto: PASS
- Concepts hit: rwenzori
- Explanation: From your lesson: Mount Rwenzori is the highest mountain in Uganda and it is found in the west.
- **Verdict (`07_physical_features_p5_sst,2`): ______**

**3. What is the highest peak of Mount Rwenzori?**

- A. sources of rivers
- B. called Margherita ←
- C. a long deep valley
- D. pushed up

- Auto: PASS
- Concepts hit: rwenzori
- Explanation: From your lesson: The highest peak of Mount Rwenzori is called Margherita.
- **Verdict (`07_physical_features_p5_sst,3`): ______**

**4. Which extinct volcano is found in the east of Uganda?**

- A. A lake
- B. Lake Albert
- C. Crater lakes
- D. mount Elgon ←

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: Mount Elgon is an extinct volcano that is found in the east of Uganda.
- **Verdict (`07_physical_features_p5_sst,4`): ______**

**5. What is mount Moroto?**

- A. a rift valley lake found in the western part of Uganda
- B. a mountain found in the north east of Uganda in Karamoja ←
- C. mountains that form when molten rock comes out of the earth
- D. the largest lake in Uganda and in the whole of Africa

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: Mount Moroto is a mountain found in the north east of Uganda in Karamoja.
- **Verdict (`07_physical_features_p5_sst,5`): ______**

**6. What is a lake?**

- A. a large body of water that is surrounded by land ←
- B. mountains that form when molten rock comes out of the earth
- C. a shallow lake found in the central part of Uganda
- D. a block mountain while Mount Elgon is a volcanic mountain

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: A lake is a large body of water that is surrounded by land.
- **Verdict (`07_physical_features_p5_sst,6`): ______**

**7. What is a river?**

- A. a shallow lake found in the central part of Uganda
- B. a block mountain while Mount Elgon is a volcanic mountain
- C. used for generating hydro electricity at Owen Falls
- D. a natural stream of water flowing towards a lake ←

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: A river is a natural stream of water flowing towards a lake, a sea or an ocean.
- **Verdict (`07_physical_features_p5_sst,7`): ______**

---

## Fractions (Mathematics, P.5)

**1. What is a fraction?**

- A. a fraction whose numerator is smaller than its denominator
- B. a number that represents a part of a whole ←
- C. fractions that have the same value but different numbers
- D. the number written below the line in a fraction

- Auto: PASS
- Concepts hit: fraction_definition
- Explanation: From your lesson: A fraction is a number that represents a part of a whole.
- **Verdict (`08_fractions_p5_math,1`): ______**

**2. What is the numerator?**

- A. a number that represents a part of a whole
- B. fractions that have the same value but different numbers
- C. the number written above the line in a fraction ←
- D. the number written below the line in a fraction

- Auto: PASS
- Concepts hit: numerator
- Explanation: From your lesson: The numerator is the number written above the line in a fraction.
- **Verdict (`08_fractions_p5_math,2`): ______**

**3. What is the denominator?**

- A. a fraction whose numerator is smaller than its denominator
- B. a number that represents a part of a whole
- C. the number written below the line in a fraction ←
- D. fractions that have the same value but different numbers

- Auto: PASS
- Concepts hit: denominator
- Explanation: From your lesson: The denominator is the number written below the line in a fraction.
- **Verdict (`08_fractions_p5_math,3`): ______**

**4. What is a mixed number?**

- A. the number written below the line in a fraction
- B. a number that has a whole number part and a fraction part ←
- C. a number that represents a part of a whole
- D. the number written above the line in a fraction

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: A mixed number is a number that has a whole number part and a fraction part.
- **Verdict (`08_fractions_p5_math,4`): ______**

**5. What are equivalent fractions?**

- A. a fraction whose numerator is smaller than its denominator
- B. the number written below the line in a fraction
- C. the number written above the line in a fraction
- D. fractions that have the same value but different numbers ←

- Auto: PASS
- Concepts hit: equivalent_fractions
- Explanation: From your lesson: Equivalent fractions are fractions that have the same value but different numbers.
- **Verdict (`08_fractions_p5_math,5`): ______**

---

## Parts of Speech (English, P.6)

**1. What is a noun?**

- A. a word that describes a verb
- B. a word that names a person ←
- C. used in place of the noun Mary
- D. a word that joins words

- Auto: PASS
- Concepts hit: noun
- Explanation: From your lesson: A noun is a word that names a person, a place, an animal or a thing.
- **Verdict (`09_parts_of_speech_p6_english,1`): ______**

**2. What is a pronoun?**

- A. a noun that names a particular person or place and begins
- B. a word that is used in place of a noun ←
- C. a verb that is used together with a main verb
- D. a noun that names a group of things taken together

- Auto: PASS
- Concepts hit: pronoun
- Explanation: From your lesson: A pronoun is a word that is used in place of a noun.
- **Verdict (`09_parts_of_speech_p6_english,2`): ______**

**3. What is a helping verb?**

- A. a verb that is used together with a main verb ←
- B. a noun that names a group of things taken together
- C. a word that shows the position or relationship of a noun
- D. a word that is used in place of a noun

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: A helping verb is a verb that is used together with a main verb, such as is or have.
- **Verdict (`09_parts_of_speech_p6_english,3`): ______**

**4. What is an adjective?**

- A. a noun that names a group of things taken together
- B. a word that expresses a sudden strong feeling
- C. a word that describes a noun or a pronoun ←
- D. a word that is used in place of a noun

- Auto: PASS
- Concepts hit: pronoun, adjective
- Explanation: From your lesson: An adjective is a word that describes a noun or a pronoun.
- **Verdict (`09_parts_of_speech_p6_english,4`): ______**

**5. What is a preposition?**

- A. a noun that names any one of a group of things
- B. a word that shows the position or relationship of a noun ←
- C. a noun that names a particular person or place and begins
- D. a noun that names something we can think of but cannot touch

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: A preposition is a word that shows the position or relationship of a noun
- **Verdict (`09_parts_of_speech_p6_english,5`): ______**

**6. What is an interjection?**

- A. a word that describes a noun or a pronoun
- B. a word that expresses a sudden strong feeling ←
- C. used in place of the noun Mary
- D. eight parts of speech in the English language

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: An interjection is a word that expresses a sudden strong feeling.
- **Verdict (`09_parts_of_speech_p6_english,6`): ______**

---

## Personal Hygiene and Disease Prevention (Health Education, P.4)

**1. What is personal hygiene?**

- A. prevented by sleeping under a treated mosquito net and by draining
- B. the practice of keeping our bodies and our clothes clean ←
- C. a disease that is caused by drinking water that contains germs
- D. the washing of the whole body with clean water and soap

- Auto: PASS
- Concepts hit: hygiene_definition
- Explanation: From your lesson: Personal hygiene is the practice of keeping our bodies and our clothes clean
- **Verdict (`10_hygiene_disease_p4_health,1`): ______**

**2. What is a germ?**

- A. a skin disease that is caused by a fungus and it forms
- B. a skin disease that is caused by a small insect that burrows
- C. the giving of a vaccine to protect a person against a disease
- D. a very small living thing that causes disease and cannot be seen ←

- Auto: PASS
- Concepts hit: germ
- Explanation: From your lesson: A germ is a very small living thing that causes disease and cannot be seen
- **Verdict (`10_hygiene_disease_p4_health,2`): ______**

**3. What is bathing?**

- A. prevented by sleeping under a treated mosquito net and by draining
- B. the practice of keeping our bodies and our clothes clean
- C. a disease that is caused by drinking water that contains germs
- D. the washing of the whole body with clean water and soap ←

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: Bathing is the washing of the whole body with clean water and soap.
- **Verdict (`10_hygiene_disease_p4_health,3`): ______**

**4. What is malaria?**

- A. prevented by sleeping under a treated mosquito net and by draining ←
- B. a disease that is caused by drinking water that contains germs
- C. the washing of the whole body with clean water and soap
- D. a skin disease that is caused by a fungus and it forms

- Auto: PASS
- Concepts hit: malaria
- Explanation: From your lesson: Malaria is prevented by sleeping under a treated mosquito net and by draining
- **Verdict (`10_hygiene_disease_p4_health,4`): ______**

**5. What is immunisation?**

- A. a skin disease that is caused by a small insect that burrows
- B. a skin disease that is caused by a fungus and it forms
- C. the giving of a vaccine to protect a person against a disease ←
- D. a disease that is caused by drinking water that contains germs

- Auto: PASS
- Concepts hit: immunisation
- Explanation: From your lesson: Immunisation is the giving of a vaccine to protect a person against a disease.
- **Verdict (`10_hygiene_disease_p4_health,5`): ______**

**6. What are children in Uganda immunised against?**

- A. watery diarrhoea
- B. six killer diseases ←
- C. high fever
- D. a very small living thing

- Auto: PASS
- Concepts hit: none
- Explanation: From your lesson: Children in Uganda are immunised against six killer diseases.
- **Verdict (`10_hygiene_disease_p4_health,6`): ______**

