using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using Windows.Media.Editing;
using Windows.Media.MediaProperties;
using Windows.Media.Transcoding;
using Windows.Storage;

internal static class RenderPromo
{
    private sealed class Scene
    {
        public string Name { get; set; }
        public double Seconds { get; set; }
    }

    private static readonly IReadOnlyList<Scene> Scenes = new[]
    {
        new Scene { Name = "01-meet-jotcue.png", Seconds = 4.5 },
        new Scene { Name = "02-start-a-note.png", Seconds = 5.5 },
        new Scene { Name = "03-plans-to-tasks.png", Seconds = 6.0 },
        new Scene { Name = "04-add-the-cue.png", Seconds = 7.5 },
        new Scene { Name = "05-find-anything.png", Seconds = 7.5 },
        new Scene { Name = "06-start-writing.png", Seconds = 5.5 },
    };

    public static void Main(string[] args)
    {
        if (args.Length != 1) throw new ArgumentException("Pass the promo directory.");
        Run(args[0]).GetAwaiter().GetResult();
    }

    private static async Task Run(string promoDirectory)
    {
        var composition = new MediaComposition();
        var sceneDirectory = Path.Combine(promoDirectory, "scenes");
        foreach (var scene in Scenes)
        {
            var file = await StorageFile.GetFileFromPathAsync(Path.Combine(sceneDirectory, scene.Name));
            var clip = await MediaClip.CreateFromImageFileAsync(file, TimeSpan.FromSeconds(scene.Seconds));
            composition.Clips.Add(clip);
        }

        await AddAudio(composition, Path.Combine(promoDirectory, "music-bed.wav"), 0.16);
        await AddAudio(composition, Path.Combine(promoDirectory, "narration.wav"), 1.0);

        var folder = await StorageFolder.GetFolderFromPathAsync(promoDirectory);
        var output = await folder.CreateFileAsync("jotcue-user-promo.mp4", CreationCollisionOption.ReplaceExisting);
        var profile = MediaEncodingProfile.CreateMp4(VideoEncodingQuality.HD1080p);
        profile.Video.Width = 1080;
        profile.Video.Height = 1920;
        profile.Video.Bitrate = 8000000;
        profile.Video.FrameRate.Numerator = 30;
        profile.Video.FrameRate.Denominator = 1;
        profile.Audio.Bitrate = 192000;
        profile.Audio.SampleRate = 44100;
        profile.Audio.ChannelCount = 2;

        var result = await composition.RenderToFileAsync(output, MediaTrimmingPreference.Precise, profile);
        if (result != TranscodeFailureReason.None) throw new InvalidOperationException("Video rendering failed: " + result);
        var info = new FileInfo(output.Path);
        Console.WriteLine("Saved {0} ({1:N0} bytes)", info.FullName, info.Length);
    }

    private static async Task AddAudio(MediaComposition composition, string path, double volume)
    {
        var file = await StorageFile.GetFileFromPathAsync(path);
        var track = await BackgroundAudioTrack.CreateFromFileAsync(file);
        track.Volume = volume;
        composition.BackgroundAudioTracks.Add(track);
    }
}
