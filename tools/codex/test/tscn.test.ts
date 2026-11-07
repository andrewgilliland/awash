import { describe, expect, it } from "vitest";
import { readScene } from "../server/tscn";

const SCENE = `[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/core/main.gd" id="1_main"]
[ext_resource type="PackedScene" uid="uid://x" path="res://scenes/enemies/wraith.tscn" id="enemy_wraith"]
[ext_resource type="Texture2D" path="res://assets/npcs/netter/netter.png" id="21_netter"]

[node name="Room" type="Node2D"]
script = ExtResource("1_main")

[node name="Enemies" type="Node2D" parent="."]

[node name="Wraith" parent="Enemies" instance=ExtResource("enemy_wraith")]
position = Vector2(216, 48)
haunt_left = 196.0

[node name="Netter" parent="Villagers" instance=ExtResource("enemy_wraith")]
speaker = "NETTER"
lines = PackedStringArray("My father fished.", "They glow, \\"pretty\\".")
sheet = ExtResource("21_netter")

[node name="Boss" type="CharacterBody2D" groups=["boss", "enemy"]]

[node name="ArcHitbox" type="Area2D" parent="Boss"]
damage = 15
`;

describe("reading a Godot scene", () => {
  const scene = readScene(SCENE);

  it("reads its external resources by id", () => {
    expect(scene.resources.enemy_wraith).toBe("res://scenes/enemies/wraith.tscn");
  });

  it("reads each node: its name, parent, groups, the scene it instances, and its properties", () => {
    const wraith = scene.nodes.find((node) => node.name === "Wraith");
    expect(wraith?.parent).toBe("Enemies");
    expect(wraith?.instance).toBe("res://scenes/enemies/wraith.tscn");
    expect(wraith?.properties.position).toEqual({ call: "Vector2", args: [216, 48] });
    expect(wraith?.properties.haunt_left).toBe(196);
    const boss = scene.nodes.find((node) => node.name === "Boss");
    expect(boss?.groups).toEqual(["boss", "enemy"]);
    expect(scene.nodes.find((node) => node.name === "ArcHitbox")?.properties.damage).toBe(15);
  });

  it("resolves a property naming an external resource to its path, and reads string arrays", () => {
    const netter = scene.nodes.find((node) => node.name === "Netter");
    expect(netter?.properties.sheet).toBe("res://assets/npcs/netter/netter.png");
    expect(netter?.properties.lines).toEqual(["My father fished.", 'They glow, "pretty".']);
    expect(netter?.properties.speaker).toBe("NETTER");
  });
});
